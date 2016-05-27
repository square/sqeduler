# encoding: utf-8
module Sqeduler
  module Worker
    # Uses Redis hashes to enabled and disable workers across multiple hosts.
    module KillSwitch
      SIDEKIQ_DISABLED_WORKERS = "sidekiq.disabled-workers".freeze

      def self.prepended(base)
        if base.ancestors.include?(Sqeduler::Worker::Callbacks)
          raise "Sqeduler::Worker::Callbacks must be the last module that you prepend."
        end
        base.extend(ClassMethods)
      end

      def self.disabled
        Service.redis_pool.with do |redis|
          redis.hgetall(SIDEKIQ_DISABLED_WORKERS)
        end
      end

      # rubocop:disable Style/Documentation
      module ClassMethods
        def enable
          Service.redis_pool.with do |redis|
            redis.hdel(SIDEKIQ_DISABLED_WORKERS, name)
            Service.logger.warn "#{name} has been enabled"
          end
        end

        def disable
          Service.redis_pool.with do |redis|
            redis.hset(SIDEKIQ_DISABLED_WORKERS, name, Time.now)
            Service.logger.warn "#{name} has been disabled"
          end
        end

        def disabled?
          Service.redis_pool.with do |redis|
            redis.hexists(SIDEKIQ_DISABLED_WORKERS, name)
          end
        end

        def enabled?
          !disabled?
        end
      end
      # rubocop:enable Style/Documentation

      def perform(*args)
        if self.class.disabled?
          Service.logger.warn "#{self.class.name} is currently disabled."
        else
          super
        end
      end
    end
  end
end
