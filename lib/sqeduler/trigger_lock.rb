# encoding: utf-8
module Sqeduler
  module Scheduler
    # Super simple facade to match RufusScheduler's expectations of how
    # a lock behaves.
    class TriggerLock < RedisLock
      SCHEDULER_LOCK_KEY = "sidekiq_scheduler_lock".freeze

      def initialize
        super(SCHEDULER_LOCK_KEY, :expiration => 60.seconds, :timeout => 0)
      end

      def lock
        # Locking should:
        # - not block
        # - return true if already acquired
        # - refresh the lock if already acquired
        refresh || super
      end

      private

      def redis_pool
        # uses a separate connection pool
        @pool ||= ConnectionPool.new(:timeout => 0, :size => 1) do
          Redis.new(Service.config.redis_config)
        end
      end
    end
  end
end
