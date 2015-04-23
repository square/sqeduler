# encoding: utf-8
require "benchmark"
module Sqeduler
  module Worker
    # Basic callbacks for worker events.
    module Callbacks
      def perform(*args)
        before_start
        duration = Benchmark.realtime { super }
        on_success(duration)
      rescue StandardError => e
        on_failure(e)
        raise
      end

      private

      # provides an oppurtunity to log when the job has started (maybe create a
      # stateful db record for this job run?)
      def before_start
        Service.logger.info "Starting #{self.class.name} at #{Time.now} in process ID #{Process.pid}"
        super if defined?(super)
      end

      # callback for successful run of this job
      def on_success(total_time)
        Service.logger.info "#{self.class.name} completed at #{Time.now}. Total time #{total_time}"
        super if defined?(super)
      end

      # callback for when failues in this job occur
      def on_failure(e)
        Service.logger.error "#{self.class.name} failed with exception #{e}"
        super if defined?(super)
      end
    end
  end
end
