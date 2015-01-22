# encoding: utf-8

module Sqeduler
  # Based on redis-objects' implementation of a Redis::Lock and
  # redis-mutex's implementation of RedisMutex
  class RedisLock
    class LockTimeoutError < StandardError; end
    SLEEP_TIME = 0.1

    attr_reader :key, :timeout, :expiration, :expiration_epoch

    def initialize(key, options = {})
      @key = key
      @expiration = options[:expiration]
      @timeout = options[:timeout] || 5.seconds
      @locked = false
    end

    def lock
      true if locked?
      poll_for_lock
      if locked?
        Service.logger.debug "Retrieved lock for #{key}"
        true
      else
        Service.logger.debug "Could not retrieve lock #{key}"
        false
      end
    end

    def unlock
      redis_pool.with do |redis|
        success = if can_delete_lock?
                    redis.del(key)
                    Service.logger.debug "Released lock for #{key}."
                    true
                  else
                    Service.logger.debug "Unable to release lock for #{key}. Someone else might have it."
                    false
                  end
        @locked = false
        @expiration_epoch = nil
        success
      end
    end

    def refresh
      if locked?
        take_lock(true)
      else
        false
      end
    end

    def locked?
      # Created the lock and the lock has not expired
      @locked && !lock_expired?
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

    private

    def poll_for_lock
      start = Time.now
      ran_at_least_once = false
      while Time.now - start < timeout || !ran_at_least_once
        break if take_lock || (lock_expired? && take_lock(true))
        ran_at_least_once = true
        sleep SLEEP_TIME
      end
    end

    def take_lock(overwrite = false)
      redis_pool.with do |redis|
        previous_epoch = expiration_epoch
        @expiration_epoch = gen_expiration_epoch
        if overwrite
          # Since GETSET returns the old value of the lock, if the old expiration
          # is still in the past or it was our previous value for expiration_epoch,
          # we know no one else has expired the locked and we now have it.
          old_expiration = redis.getset(key, expiration_epoch).to_f
          @locked = old_expiration < Time.now.to_f || old_expiration == previous_epoch
        else
          @locked = redis.setnx(key, expiration_epoch)
        end
        @locked
      end
    end

    def lock_expired?
      redis_pool.with do |redis|
        return false unless expiration
        old_expiration = redis.get(key).to_f
        old_expiration < Time.now.to_f
      end
    end

    def can_delete_lock?
      return true if expiration.nil?
      # cannot release the lock if it's possible that
      # we're no longer the owner
      expiration_epoch > Time.now.to_f
    end

    def gen_expiration_epoch
      if expiration
        (Time.now + expiration.to_f + 1).to_f
      else
        1
      end
    end

    def redis_pool
      Service.config.sync_pool
    end
  end
end
