# frozen_string_literal: true

require "spec_helper"
require "./spec/fixtures/fake_worker"

RSpec.describe Sqeduler::Worker::KillSwitch do
  describe ".disabled" do
    before do
      Sqeduler::Service.config = Sqeduler::Config.new(
        :redis_hash => REDIS_CONFIG,
        :logger     => Logger.new(STDOUT).tap { |l| l.level = Logger::DEBUG }
      )
    end
    after { FakeWorker.enable }

    it "lists the disabled workers" do
      expect(Sqeduler::Worker::KillSwitch.disabled).to eq({})
      time = Time.now
      Timecop.freeze(time) { FakeWorker.disable }
      expect(Sqeduler::Worker::KillSwitch.disabled).to eq("FakeWorker" => time.to_s)
    end
  end
end
