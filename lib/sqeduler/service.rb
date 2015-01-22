# encoding: utf-8
module Sqeduler
  class Service
    SCHEDULER_TIMEOUT = 60

    class << self
      attr_accessor :config

      def logger
        config.logger
      end

      def start
        fail "No config provided" unless config
        start_sidekiq_server
        start_sidekiq_client
        start_scheduler
      end

      def handle_exception(e)
        config.exception_notifier(e)
      end

      def start_sidekiq_server
        logger.info "Initializing Sidekiq server"
        ::Sidekiq.configure_server do |config|
          config.redis = Service.config.redis_config
          config.on(:shutdown) do
            # Make sure any scheduling locks are released on shutdown.
            Sidekiq::Scheduler.rufus_scheduler.stop
          end
          Service.config.on_server_start(config) if Service.config.on_server_start
        end
      end

      def start_sidekiq_client
        logger.info "Initializing Sidekiq client"
        ::Sidekiq.configure_client do |config|
          config.redis = Service.config.redis_config
          Service.config.on_client_start(config) if Service.config.on_client_start
        end
      end

      def start_scheduler
        logger.info "Initializing Sidekiq::Scheduler with schedule #{config.schedule_path}"
        ::Sidekiq::Scheduler.rufus_scheduler_options = {
          :trigger_lock => TriggerLock.new
        }
        ::Sidekiq.schedule = YAML.load_file(config.schedule_path)
      end
    end
  end
end
