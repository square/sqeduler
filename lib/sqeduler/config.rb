# encoding: utf-8
module Sqeduler
  # Config for Sqeduler. Will raise when required values are not provided.
  class Config
    attr_accessor :logger, :redis_config, :schedule_path, :exception_notifier,
                  :on_server_start, :on_client_start

    attr_reader :opts

    def initialize(opts = {})
      @opts = opts
      config_logger
      self.redis_config = fetch_or_raise(:redis_config)
      self.schedule_path = fetch_or_raise(:schedule_path)
      self.exception_notifier = fetch_or_raise(:exception_notifier)
      self.on_server_start = opts[:on_server_start]
      self.on_client_start = opts[:on_client_start]
    end

    def sync_pool
      return @sync_pool if defined?(@sync_pool)
      pool_size = fetch_or_raise(:sync_pool_size)
      pool_timeout = fetch_or_raise(:sync_pool_timeout)
      @sync_pool = ConnectionPool.new(
                    :size => pool_size,
                    :timeout => pool_timeout
                  ) do
                    Redis.new(redis_config)
                  end
    end

    private

    def fetch_or_raise(key)
      opts[key] || fail(ArgumentError, "No #{key} provided to config.")
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
