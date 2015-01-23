# encoding: utf-8
module Sqeduler
  # Uses eval_sha to execute server-side scripts on redis.
  # Avoids some of the potentially racey and brittle depencies on Time-based
  # redis locks in other locking libraries.
  class RedisLock
    include RedisScripts

    class LockTimeoutError < StandardError; end
    SLEEP_TIME = 0.1
    attr_reader :key, :timeout

    def initialize(key, options = {})
      @key = key
      @expiration = options[:expiration]
      @timeout = options[:timeout] || 5.seconds
      @locked = false
    end

    def lock
      message = if @expiration
        "Try to acquire lock with #{key}, expiration: #{@expiration} sec, timeout: #{timeout} sec"
      else
        "Try to acquire lock with #{key}, expiration: none, timeout: #{timeout} sec"
      end

      Service.logger.info message

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
      if release_lock
        Service.logger.info "Released lock #{key}."
        true
      else
        Service.logger.info "Cannot release lock #{key}."
        false
      end
    end

    def refresh
      if refresh_lock
        Service.logger.info "Refreshed lock #{key} with value #{lock_value}"
        true
      else
        Service.logger.info "Cannot refresh lock #{key} with value #{lock_value}"
        false
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

    def expiration_milliseconds
      # expiration needs to be an integer
      @expiration ? (@expiration * 1000).to_i : 0
    end

    private

    def lock_value
      @lock_value ||= LockValue.new.value
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
        redis.set(key, lock_value, :nx => true, :px => expiration_milliseconds)
      end
    end

    def redis_pool
      Service.config.sync_pool
    end
  end
end
