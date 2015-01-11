# encoding: utf-8
# Sqeduler::BaseWorker is class that provides common infrastructure for Sidekiq workers:
# - Synchronization of jobs across multiple hosts `Sqeduler::BaseWorker.synchronize_jobs`.
# - Basic callbacks for job events that child classes can observe.
module Sqeduler
  class BaseWorker
    def self.synchronize_jobs(mode, opts = {})
      @synchronize_jobs_mode = mode
      @synchronize_jobs_timeout = opts[:timeout] || 5.seconds
      @synchronize_jobs_expiration = opts[:expiration]
    end

    class << self
      attr_reader :synchronize_jobs_mode
    end

    class << self
      attr_reader :synchronize_jobs_timeout
    end

    class << self
      attr_reader :synchronize_jobs_expiration
    end

    def self.lock_name(*args)
      if args.present?
        "#{name}-#{args.join}"
      else
        name
      end
    end

    def perform(*args)
      before_start
      Service.logger.info "Starting #{self.class.name} #{start_time}"
      if self.class.synchronize_jobs_mode == :one_at_a_time
        if self.class.synchronize_jobs_expiration
          start = Time.current
          do_work_with_lock(*args)
          duration = Time.current - start
          on_schedule_collision if duration > self.class.synchronize_jobs_expiration
        else
          do_work_with_lock(*args)
        end
      else
        do_work(*args)
      end
      Service.logger.info "#{self.class.name} completed at #{end_time}. Total time #{total_time}"
      on_success
    rescue => e
      on_failure(e)
      Service.logger.error "#{self.class.name} failed!"
      Service.logger.error e
      notify_exception(e)
      raise e
    end

    private

    # provides an oppurtunity to log when the job has started to create a
    # stateful db record for this job run
    def before_start; end

    # callback for successful run of this job
    def on_success; end

    # callback for when failues in this job occur
    def on_failure(_e); end

    # callback for when a lock cannot be obtained
    def on_lock_timeout; end

    # callback for when the job expiration is too short, less < time it took
    # perform the actual work
    def on_schedule_collision; end

    def notify_exception(e)
      Service.handle_exception(e)
    end

    def do_work_with_lock(*args)
      RedisLock.with_lock(
        self.class.lock_name(*args),
        :expiration => self.class.synchronize_jobs_expiration,
        :timeout => self.class.synchronize_jobs_timeout
      ) do
        do_work(*args)
      end
    rescue RedisLock::LockTimeoutError
      Service.logger.warn "#{self.class.name} unable to acquire lock '#{self.class.lock_name(*args)}'. Aborting."
      on_lock_timeout
    end

    def start_time
      @start_time ||= Time.current
    end

    def end_time
      @end_time ||= Time.current
    end

    def total_time
      time_duration(end_time - start_time)
    end

    def time_elapsed
      time_duration(Time.current - start_time)
    end

    private

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
  end
end
