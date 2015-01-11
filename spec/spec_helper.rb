# encoding: utf-8

require "rspec"
require "sqeduler"
require "pry"

REDIS_CONFIG = {
  :host => "localhost",
  :db => 1
}
TEST_REDIS = Redis.new(REDIS_CONFIG)

RSpec.configure do |config|
  config.before(:each) do
    TEST_REDIS.flushdb
  end

  config.disable_monkey_patching!
end
