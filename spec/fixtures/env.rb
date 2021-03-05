# frozen_string_literal: true

require "sqeduler"
require_relative "fake_worker"

Sidekiq.logger = Logger.new($stdout).tap { |l| l.level = Logger::DEBUG }

Sqeduler::Service.config = Sqeduler::Config.new(
  redis_hash: {
    host: "localhost",
    db: 1,
    namespace: "sqeduler-tests"
  },
  logger: Sidekiq.logger,
  schedule_path: "#{__dir__}/schedule.yaml",
  on_server_start: proc do |_config|
    Sqeduler::Service.logger.info "Received on_server_start callback"
  end,
  on_client_start: proc do |_config|
    Sqeduler::Service.logger.info "Received on_client_start callback"
  end
)
Sqeduler::Service.start
