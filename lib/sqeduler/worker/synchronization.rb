# encoding: utf-8
require "benchmark"
require "active_support/core_ext/class/attribute"

module Sqeduler
  module Worker
    # Module that provides common synchronization infrastructure
    # of workers across multiple hosts `Sqeduler::BaseWorker.synchronize_jobs`.
    module Synchronization
      def self.prepended(base)
        if base.ancestors.include?(Sqeduler::Worker::Callbacks)
          raise "Sqeduler::Worker::Callbacks must be the last module that you prepend."
        end

        base.extend(ClassMethods)
        base.class_attribute :synchronize_jobs_mode
        base.class_attribute :synchronize_jobs_expiration
        base.class_attribute :synchronize_jobs_timeout
      end

      # rubocop:disable Style/Documentation
      module ClassMethods
        def synchronize(mode, opts = {})
          self.synchronize_jobs_mode = mode
          self.synchronize_jobs_timeout = opts[:timeout] || 0
          self.synchronize_jobs_expiration = opts[:expiration]
          return if synchronize_jobs_expiration
          raise ArgumentError, ":expiration is required!"
        end

        def sync_lock_key(*args)
          if args.empty?
            name
          else
            "#{name}-#{args.join}"
          end
        end
      end
      # rubocop:enable Style/Documentation

      def perform(*args)
        if self.class.synchronize_jobs_mode == :one_at_a_time
          perform_locked(self.class.sync_lock_key(*args)) do
            perform_timed do
              super
            end
          end
        else
          super
        end
      end

      private

      # callback for when a lock cannot be obtained
      def on_lock_timeout(key)
        Service.logger.warn(
          "#{self.class.name} unable to acquire lock '#{key}'. Aborting."
        )
        super if defined?(super)
      end

      # callback for when the job expiration is too short, less < time it took
      # perform the actual work
      SCHEDULE_COLLISION_MARKER = "%s took %s but has an expiration of %p sec. Beware of race conditions!".freeze
      def on_schedule_collision(duration)
        Service.logger.warn(
          format(
            SCHEDULE_COLLISION_MARKER,
            self.class.name,
            time_duration(duration),
            self.class.synchronize_jobs_expiration
          )
        )
        super if defined?(super)
      end

      def perform_timed(&block)
        duration = Benchmark.realtime(&block)
        on_schedule_collision(duration) if duration > self.class.synchronize_jobs_expiration
      end

      def perform_locked(sync_lock_key, &work)
        RedisLock.with_lock(
          sync_lock_key,
          :expiration => self.class.synchronize_jobs_expiration,
          :timeout => self.class.synchronize_jobs_timeout,
          &work
        )
      rescue RedisLock::LockTimeoutError
        on_lock_timeout(sync_lock_key)
      end

      # rubocop:disable Metrics/AbcSize
      def time_duration(timespan)
        rest, secs = timespan.divmod(60) # self is the time difference t2 - t1
        rest, mins = rest.divmod(60)
        days, hours = rest.divmod(24)

        result = []
        result << "#{days} Days" if days > 0
        result << "#{hours} Hours" if hours > 0
        result << "#{mins} Minutes" if mins > 0
        result << "#{secs.round(2)} Seconds" if secs > 0
        result.join(" ")
      end
      # rubocop:enable Metrics/AbcSize
    end
  end
end
