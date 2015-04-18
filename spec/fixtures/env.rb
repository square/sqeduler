require "sqeduler"
require_relative "fake_worker"

REDIS_CONFIG = {
  :host => "localhost",
  :db => 1,
  :namespace => "sqeduler-tests"
}
Sidekiq.logger = Logger.new(STDOUT).tap { |l| l.level = Logger::DEBUG }

Sqeduler::Service.config = Sqeduler::Config.new(
  :redis_hash => REDIS_CONFIG,
  :logger => Sidekiq.logger,
  :schedule_path => File.expand_path(File.dirname(__FILE__)) + "/schedule.yaml",
  :on_server_start => proc do |_config|
    Sqeduler::Service.logger.info "Received on_server_start callback"
  end,
  :on_client_start => proc do |_config|
    Sqeduler::Service.logger.info "Received on_client_start callback"
  end
)
Sqeduler::Service.start
