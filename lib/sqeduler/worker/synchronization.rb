# encoding: utf-8
module Sqeduler
  module Worker
    # Module that provides common synchronization infrastructure
    # of workers across multiple hosts `Sqeduler::BaseWorker.synchronize_jobs`.
    module Synchronization
      def self.prepended(base)
        if base.ancestors.include?(Sqeduler::Worker::Callbacks)
          fail "Sqeduler::Worker::Callbacks must be the last module that you prepend."
        end
        base.extend(ClassMethods)
      end

      attr_accessor :sync_lock_key

      # rubocop:disable Style/Documentation
      module ClassMethods
        attr_reader :synchronize_jobs_mode
        attr_reader :synchronize_jobs_timeout
        attr_reader :synchronize_jobs_expiration

        def synchronize(mode, opts = {})
          @synchronize_jobs_mode = mode
          @synchronize_jobs_timeout = opts[:timeout] || 5.seconds
          @synchronize_jobs_expiration = opts[:expiration]
          return if @synchronize_jobs_expiration
          fail ArgumentError, ":expiration is required!"
        end
      end
      # rubocop:enable Style/Documentation

      def perform(*args)
        self.sync_lock_key = if args.present?
          "#{self.class.name}-#{args.join}"
        else
          self.class.name
        end

        if self.class.synchronize_jobs_mode == :one_at_a_time
          perform_synchronized { super(*args) }
        else
          super
        end
      end

      private

      # callback for when a lock cannot be obtained
      def on_lock_timeout
        Service.logger.warn(
          "#{self.class.name} unable to acquire lock '#{sync_lock_key}'. Aborting."
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

      def perform_synchronized(&work)
        start = Time.now
        perform_locked(&work)
        duration = Time.now - start
        return unless duration > self.class.synchronize_jobs_expiration
        on_schedule_collision(duration)
      end

      def perform_locked(&work)
        RedisLock.with_lock(
          sync_lock_key,
          :expiration => self.class.synchronize_jobs_expiration,
          :timeout => self.class.synchronize_jobs_timeout,
          :redis => @redis
        ) do
          work.call
        end
      rescue RedisLock::LockTimeoutError
        on_lock_timeout
      end

      def start_time
        @start_time ||= Time.now
      end

      def end_time
        @end_time ||= Time.now
      end

      def total_time
        time_duration(end_time - start_time)
      end

      def time_elapsed
        time_duration(Time.now - start_time)
      end

      def notify_and_raise(e)
        on_failure(e)
      end

      # rubocop:disable Metrics/AbcSize
      def time_duration(timespan)
        rest, secs = timespan.divmod(60)  # self is the time difference t2 - t1
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
