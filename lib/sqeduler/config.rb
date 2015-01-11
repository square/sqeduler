# encoding: utf-8
module Sqeduler
  class Config
    attr_accessor :logger, :redis_config, :schedule_path, :exception_notifier,
                  :on_server_start, :on_client_start

    attr_reader :opts

    def initialize(opts = {})
      @opts = opts
      config_logger
      config_redis

      self.schedule_path = opts[:schedule_path]
      fail ArgumentError, "No schedule_path provided." unless schedule_path

      self.exception_notifier = opts[:exception_notifier]
      fail ArgumentError, "No exception_notifier provided." unless exception_notifier

      self.on_server_start = opts[:on_server_start]
      self.on_client_start = opts[:on_client_start]
    end

    def sync_pool
      return @sync_pool if defined?(@sync_pool)

      pool_size = opts[:sync_pool_size]
      unless pool_size
        fail ArgumentError, "No sync_pool_size provided. Cannot create a synchronization redis pool."
      end

      pool_timeout = opts[:sync_pool_timeout]
      unless pool_timeout
        fail ArgumentError, "No sync_pool_timeout provided. Cannot create a synchronization redis pool."
      end

      @sync_pool =  ConnectionPool.new(:size => pool_size, :timeout => pool_timeout) do
                      Redis.new(redis_config)
                    end
    end

    private

    def config_redis
      self.redis_config = opts[:redis_config]
      fail ArgumentError, "No redis_config provided." unless redis_config
    end

    def config_logger
      self.logger = opts[:logger]
      return if logger
      if defined?(Rails)
        self.logger = Rails.logger
      else
        fail ArgumentError, "No logger provided and Rails.logger cannot be inferred"
      end
    end
  end
end
