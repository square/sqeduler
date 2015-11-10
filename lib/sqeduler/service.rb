# encoding: utf-8
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
        fail "No config provided" unless config
        config_sidekiq_server
        config_sidekiq_client
        config_scheduler
      end

      def verify_redis_pool(redis_pool)
        return @verified if defined?(@verified)
        redis_pool.with do |redis|
          version = redis.info["redis_version"]
          unless Gem::Version.new(version) >= Gem::Version.new(MINIMUM_REDIS_VERSION)
            fail "Must be using redis >= #{MINIMUM_REDIS_VERSION}"
          end
          @verified = true
        end
      end

      def config_sidekiq_server
        logger.info "Initializing Sidekiq server"
        ::Sidekiq.configure_server do |config|
          setup_sidekiq_redis(config)
          if Service.scheduling?
            config.on(:shutdown) do
              # Make sure any scheduling locks are released on shutdown.
              Sidekiq::Scheduler.rufus_scheduler.stop
            end
          end

          # the server can also enqueue jobs
          config.client_middleware do |chain|
            chain.add(Sqeduler::Middleware::KillSwitch)
          end

          Service.config.on_server_start.call(config) if Service.config.on_server_start
        end
      end

      def config_sidekiq_client
        logger.info "Initializing Sidekiq client"
        ::Sidekiq.configure_client do |config|
          setup_sidekiq_redis(config)
          if Service.config.on_client_start
            Service.config.on_client_start.call(config)
          end

          config.client_middleware do |chain|
            chain.add(Sqeduler::Middleware::KillSwitch)
          end
        end
      end

      def setup_sidekiq_redis(config)
        return if Service.config.redis_hash.nil? || Service.config.redis_hash.empty?
        config.redis = Service.config.redis_hash
      end

      def config_scheduler
        if scheduling?
          logger.info "Initializing Sidekiq::Scheduler with schedule #{config.schedule_path}"
          ::Sidekiq::Scheduler.rufus_scheduler_options = {
            :trigger_lock => TriggerLock.new
          }
          ::Sidekiq.schedule = parse_schedule(config.schedule_path)
        else
          logger.warn "No schedule_path provided. Not starting Sidekiq::Scheduler."
        end
      end

      def parse_schedule(path)
        fail "Schedule file #{path} does not exist!" unless File.exist?(path)
        file_contents = File.read(path)
        YAML.load(ERB.new(file_contents).result)
      end

      def scheduling?
        !config.schedule_path.to_s.empty?
      end

      # A singleton redis ConnectionPool for Sidekiq::Scheduler,
      # Sqeduler::Worker::Synchronization, Sqeduler::Worker::KillSwitch. Should be
      # separate from Sidekiq's so that we don't saturate the client and server connection
      # pools.
      def redis_pool
        @redis_pool ||= begin
          redis = { :namespace => "sqeduler" }.merge(config.redis_hash)
          ::Sidekiq::RedisConnection.create(redis).tap do |redis_pool|
            verify_redis_pool(redis_pool)
          end
        end
      end

      def logger
        return config.logger if config.logger
        if defined?(Rails)
          Rails.logger
        else
          fail ArgumentError, "No logger provided and Rails.logger cannot be inferred"
        end
      end
    end
  end
end
