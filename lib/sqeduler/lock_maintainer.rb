# frozen_string_literal: true

module Sqeduler
  # This is to ensure that if you set your jobs to run one a time and something goes wrong
  # causing a job to run for a long time, your lock won't expire.
  # This doesn't stop long running jobs, it just ensures you only end up with one long running job
  # rather than 20 of them.
  class LockMaintainer
    RUN_INTERVAL = 30
    RUN_JITTER = (1..5).freeze

    def initialize
      @class_with_locks = {}
    end

    # This is only done when we initialize Sqeduler, don't need to worry about threading
    def run
      @maintainer_thread ||= Thread.new do
        loop do
          begin
            if redis_lock.lock
              begin
                synchronize
              ensure
                redis_lock.unlock
              end
            end
          rescue StandardError => ex
            Service.logger.error "[#{self.class}] #{ex.class}, #{ex.message}"
          end

          sleep RUN_INTERVAL + rand(RUN_JITTER)
        end
      end
    end

    private

    def synchronize
      now = Time.now.to_i

      Service.redis_pool.with do |redis|
        redis.pipelined do
          workers.each do |_worker, _tid, args|
            # No sense in pinging if it's not been running long enough to matter
            next if (now - args["run_at"]) < RUN_INTERVAL

            klass = str_to_class(args["payload"]["class"])
            next unless klass

            lock_key = klass.sync_lock_key(*args["payload"]["args"])

            # This works because EXPIRE does not recreate the key, it only resets the expiration.
            # We don't have to worry about atomic operations or anything like that.
            # If the job finishes in the interim and deletes the key nothing will happen.
            redis.expire(lock_key, klass.synchronize_jobs_expiration)

            Service.logger.debug "[#{self.class}] Refreshing lock on '#{lock_key}" \
              "to #{klass.synchronize_jobs_expiration} seconds"
          end
        end
      end
    end

    # Not all classes will use exclusive locks
    def str_to_class(class_name)
      return @class_with_locks[class_name] unless @class_with_locks[class_name].nil?

      klass = class_name.constantize
      if klass.respond_to?(:synchronize_jobs_mode)
        # We only care about exclusive jobs that are long running
        if klass.synchronize_jobs_mode == :one_at_a_time && klass.synchronize_jobs_expiration >= RUN_INTERVAL
          Service.logger.debug "[#{self.class}] Adding #{class_name} to the whitelist of classes that have locks"
          return @class_with_locks[class_name] = klass
        end
      end

      Service.logger.debug "[#{self.class}] Adding #{class_name} to the blacklist of classes that have locks"
      @class_with_locks[class_name] = false
    end

    def redis_lock
      @redis_lock ||= RedisLock.new("sqeduler-lock-maintainer", :expiration => 60, :timeout => 0)
    end

    def workers
      @workers ||= Sidekiq::Workers.new
    end
  end
end
