# encoding: utf-8
# Based on redis-objects' implementation of a Redis::Lock and redis-mutex's implementation of RedisMutex
module Sqeduler
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
      redis_pool.with do |redis|
        start = Time.now
        if timeout == 0
          @expiration_epoch = gen_expiration_epoch
          @locked = redis.setnx(key, @expiration_epoch)
        else
          while Time.now - start < timeout
            break if @locked

            unless expiration.nil?
              old_expiration = redis.get(key).to_f

              if old_expiration < Time.now.to_f
                # If it's expired, use GETSET to update it.
                @expiration_epoch = gen_expiration_epoch
                old_expiration = redis.getset(key, @expiration_epoch).to_f

                # Since GETSET returns the old value of the lock, if the old expiration
                # is still in the past, we know no one else has expired the locked
                # and we now have it.
                if old_expiration < Time.now.to_f
                  @locked = true
                  break
                end
              end
            end

            sleep SLEEP_TIME
          end
        end

        if @locked
          Service.logger.debug "Retrieved lock for #{key}"
        else
          Service.logger.debug "Could not retrieve lock #{key}"
        end
        @locked
      end
    end

    def unlock
      redis_pool.with do |redis|
        if !expiration || @expiration_epoch > Time.now.to_f
          # cannot release the lock if it's possible that
          # we're no longer the owner
          redis.del(key)
          Service.logger.debug "Released lock for #{key}."
          true
        else
          Service.logger.debug "Unable to release lock for #{key}. Someone else might have it."
          false
        end
      end
    end

    def refresh
      redis_pool.with do |redis|
        @expiration_epoch = gen_expiration_epoch
        redis.set(key, @expiration_epoch)
      end
    end

    def locked?
      @locked
    end

    def self.with_lock(key, options)
      fail "Block is required" unless block_given?
      mutex = new(key, options)
      if mutex.lock
        begin
          yield
        ensure
          mutex.unlock
        end
      else
        fail LockTimeoutError, "Timed out trying to get #{key} lock. Exceeded #{mutex.timeout} sec"
      end
    end

    private

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
