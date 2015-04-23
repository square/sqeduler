require "active_support/inflector/methods"

module Sqeduler
  module Middleware
    # Verifies that a worker class is enabled before pushing the job into Redis.
    # Prevents disabled jobs from getting enqueued. To disable a worker, use
    # Sqeduler::Worker::KillSwitch.
    class KillSwitch
      def call(worker, _msg, _queue, _redis_pool)
        worker_klass = normalized_worker_klass(worker)
        if worker_enabled?(worker_klass)
          yield
        else
          Service.logger.warn "#{worker_klass.name} is currently disabled. Will not be enqueued."
          false
        end
      end

      def normalized_worker_klass(worker)
        # worker_class can be String or a Class
        # SEE: https://github.com/mperham/sidekiq/wiki/Middleware
        if worker.is_a?(String)
          worker.constantize
        else
          worker
        end
      end

      def worker_enabled?(worker_klass)
        !worker_klass.respond_to?(:enabled?) || worker_klass.enabled?
      end
    end
  end
end
