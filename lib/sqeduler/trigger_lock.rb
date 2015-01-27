# encoding: utf-8
module Sqeduler
  # Super simple facade to match RufusScheduler's expectations of how
  # a trigger_lock behaves.
  class TriggerLock < RedisLock
    SCHEDULER_LOCK_KEY = "sidekiq_scheduler_lock".freeze

    def initialize
      super(SCHEDULER_LOCK_KEY, :expiration => 60, :timeout => 0)
    end

    def lock
      # Locking should:
      # - not block
      # - return true if already acquired
      # - refresh the lock if already acquired
      refresh || super
    end
  end
end
