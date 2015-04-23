# encoding: utf-8
require "pry"
require "rspec"
require "sqeduler"
require "timecop"

REDIS_CONFIG = {
  :host => "localhost",
  :db => 1
}
TEST_REDIS = Redis.new(REDIS_CONFIG)

Timecop.safe_mode = true

RSpec.configure do |config|
  config.before(:each) do
    TEST_REDIS.flushdb
    Sqeduler::Service.config = nil
  end
  config.disable_monkey_patching!
end
