# encoding: utf-8
module Sqeduler
  # Simple config for Sqeduler::Service
  class Config
    attr_accessor :logger, :redis_hash, :schedule_path,
                  :on_server_start, :on_client_start, :maintain_locks

    def initialize(opts = {})
      self.redis_hash = opts[:redis_hash]
      self.schedule_path = opts[:schedule_path]
      self.on_server_start = opts[:on_server_start]
      self.on_client_start = opts[:on_client_start]
      self.logger = opts[:logger]
      self.maintain_locks = opts[:maintain_locks]
    end
  end
end
