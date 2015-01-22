# encoding: utf-8
module Sqeduler
  # Uses eval_sha to execute server-side scripts on redis.
  # Avoids some of the potentially racey and brittle depencies on Time-based
  # redis locks in other locking libraries.
  class RedisLock
    class LockTimeoutError < StandardError; end
    SLEEP_TIME = 0.1

    attr_reader :key, :timeout, :expiration

    def initialize(key, options = {})
      @key = key
      @expiration = options[:expiration]
      @timeout = options[:timeout] || 5.seconds
      @locked = false
    end

    def lock
      Service.logger.info(
        "Try to acquire lock with #{key}, expiration: #{expiration} sec, timeout: #{timeout} sec"
      )
      return true if locked?
      if poll_for_lock
        Service.logger.info "Acquired lock #{key} with value #{lock_value}"
        true
      else
        Service.logger.info "Failed to acquire lock #{key} with value #{lock_value}"
        false
      end
    end

    def unlock
      redis_pool.with do |redis|
        result = redis.evalsha(
          release_lock_sha(redis),
          :keys => [key],
          :argv => [lock_value]
        )
        if result == 1
          Service.logger.info "Released lock #{key}."
          true
        else
          Service.logger.info "Cannot release lock #{key}."
          false
        end
      end
    end

    def refresh
      redis_pool.with do |redis|
        result = redis.evalsha(
          refresh_lock_sha(redis),
          :keys => [key],
          :argv => [lock_value]
        )
        if result == 1
          Service.logger.info "Refreshed lock #{key} with value #{lock_value}"
          true
        else
          Service.logger.info "Cannot refresh lock #{key} with value #{lock_value}"
          false
        end
      end
    end

    def locked?
      redis_pool.with do |redis|
        if redis.get(key) == lock_value
          Service.logger.info "Lock #{key} with value #{lock_value} is valid"
          true
        else
          Service.logger.info "Lock #{key} with value #{lock_value} has expired or is not present"
          false
        end
      end
    end

    def self.with_lock(key, options)
      fail "Block is required" unless block_given?
      mutex = new(key, options)
      unless mutex.lock
        fail LockTimeoutError, "Timed out trying to get #{key} lock. Exceeded #{mutex.timeout} sec"
      end
      begin
        yield
      ensure
        mutex.unlock
      end
    end

    def expiration
      # expiration needs to be an integer
      if @expiration
        @expiration.to_i
      else
        0
      end
    end

    private

    def lock_value
      @lock_value ||= [hostname, process_id, thread_id].join(":")
    end

    def hostname
      local_hostname = Socket.gethostname
      Socket.gethostbyname(local_hostname).first
    rescue
      local_hostname
    end

    def process_id
      Process.pid
    end

    def thread_id
      Thread.current.object_id
    end

    def poll_for_lock
      start = Time.now
      ran_at_least_once = false
      while Time.now - start < timeout || !ran_at_least_once
        locked = take_lock
        break if locked
        ran_at_least_once = true
        sleep SLEEP_TIME
      end
      locked
    end

    def take_lock
      redis_pool.with do |redis|
        redis.set(key, lock_value, :nx => true, :ex => expiration)
      end
    end

    def refresh_lock_sha(redis)
      @refresh_lock_sha ||= begin
        script = <<-EOF
          if redis.call('GET', KEYS[1]) == false then
            if #{expiration} > 0 then
              return redis.call('SET', KEYS[1], ARGV[1], 'NX', 'EX', #{expiration}) and 1 or 0
            else
              return redis.call('SET', KEYS[1], ARGV[1], 'NX') and 1 or 0
            end
          elseif redis.call('GET', KEYS[1]) == ARGV[1] then
            if #{expiration} > 0 then
              redis.call('EXPIRE', KEYS[1], #{expiration})
            end
            if redis.call('GET', KEYS[1]) == ARGV[1] then
              return 1
            end
          end
          return 0
        EOF

        # strip leading whitespace of 10 characters
        redis.script(:load, script.gsub(/^ {10}/, ""))
      end
    end

    def release_lock_sha(redis)
      @release_lock_sha ||= begin
        script = <<-EOF
          if redis.call('GET', KEYS[1]) == ARGV[1] then
            redis.call('DEL', KEYS[1])
            return 1
          else
            return 0
          end
        EOF
        # strip leading whitespace of 10 characters
        redis.script(:load, script.gsub(/^ {10}/, ""))
      end
    end

    def redis_pool
      Service.config.sync_pool
    end
  end
end
