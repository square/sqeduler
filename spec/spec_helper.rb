# encoding: utf-8
require "pry"
require "rspec"
require "sqeduler"
require "timecop"

TEST_REDIS = Redis.new(:host => "localhost", :db => 1)

Timecop.safe_mode = true

RSpec.configure do |config|
  config.before(:each) do
    TEST_REDIS.flushdb
    Sqeduler::Service.config = nil
    REDIS_CONFIG = { :host => "localhost", :db => 1 }.clone
  end
  config.disable_monkey_patching!
end
