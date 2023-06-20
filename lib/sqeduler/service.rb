# frozen_string_literal: true

require "sidekiq"
require "sidekiq-scheduler"
module Sqeduler
  # Singleton class for configuring this Gem.
  class Service
    SCHEDULER_TIMEOUT = 60
    MINIMUM_REDIS_VERSION = "2.6.12"

    class << self
      attr_accessor :config

      def start
        raise "No config provided" unless config

        config_sidekiq_server
        config_sidekiq_client
      end

      def verify_redis_pool(redis_pool)
        return @verified if defined?(@verified)

        redis_pool.with do |redis|
          version = redis.info["redis_version"]
          unless Gem::Version.new(version) >= Gem::Version.new(MINIMUM_REDIS_VERSION)
            raise "Must be using redis >= #{MINIMUM_REDIS_VERSION}"
          end

          @verified = true
        end
      end

      def config_sidekiq_server
        logger.info "Initializing Sidekiq server"
        ::Sidekiq.configure_server do |config|
          setup_sidekiq_redis(config)
          if Service.scheduling?
            logger.info "Initializing Sidekiq::Scheduler with schedule #{::Sqeduler::Service.config.schedule_path}"

            config.on(:startup) do
              ::Sidekiq::Scheduler.rufus_scheduler_options = {
                :trigger_lock => TriggerLock.new
              }
              ::Sidekiq.schedule = ::Sqeduler::Service.parse_schedule(::Sqeduler::Service.config.schedule_path)
              ::Sidekiq::Scheduler.reload_schedule!
            end

            config.on(:shutdown) do
              # Make sure any scheduling locks are released on shutdown.
              ::Sidekiq::Scheduler.rufus_scheduler.stop
            end
          else
            logger.warn "No schedule_path provided. Not starting Sidekiq::Scheduler."
          end

          # the server can also enqueue jobs
          config.client_middleware do |chain|
            chain.add(Sqeduler::Middleware::KillSwitch)
          end

          LockMaintainer.new.run if Service.config.maintain_locks
          Service.config.on_server_start&.call(config)
        end
      end

      def config_sidekiq_client
        logger.info "Initializing Sidekiq client"
        ::Sidekiq.configure_client do |config|
          setup_sidekiq_redis(config)
          Service.config.on_client_start&.call(config)

          config.client_middleware do |chain|
            chain.add(Sqeduler::Middleware::KillSwitch)
          end
        end
      end

      def setup_sidekiq_redis(config)
        return if Service.config.redis_hash.nil? || Service.config.redis_hash.empty?

        config.redis = Service.config.redis_hash
      end

      def parse_schedule(path)
        raise "Schedule file #{path} does not exist!" unless File.exist?(path)

        file_contents = File.read(path)
        YAML.safe_load(ERB.new(file_contents).result)
      end

      def scheduling?
        !config.schedule_path.to_s.empty?
      end

      # A singleton redis ConnectionPool for Sidekiq::Scheduler,
      # Sqeduler::Worker::Synchronization, Sqeduler::Worker::KillSwitch. Should be
      # separate from Sidekiq's so that we don't saturate the client and server connection
      # pools.
      def redis_pool
        @redis_pool ||= config_redis_pool
      end

      def config_redis_pool
        redis_pool = if config.redis_pool
          config.redis_pool
        else
          # Redis requires config hash to have symbols as keys.
          redis = { :namespace => "sqeduler" }.merge(symbolize_keys(config.redis_hash))
          ::Sidekiq::RedisConnection.create(redis)
        end
        verify_redis_pool(redis_pool)
        redis_pool
      end

      def logger
        return config.logger if config.logger
        return Rails.logger if defined?(Rails)

        raise ArgumentError, "No logger provided and Rails.logger cannot be inferred"
      end

      private

      def symbolize_keys(hash)
        hash.transform_keys(&:to_sym)
      end
    end
  end
end
