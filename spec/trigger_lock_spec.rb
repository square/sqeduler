# encoding: utf-8
require "spec_helper"
require "timecop"

RSpec.describe Sqeduler::Scheduler::TriggerLock do
  context "#lock" do
    subject { described_class.new.lock }

    before do
      config = double
      allow(Sqeduler::Service).to receive(:config).and_return(config)
      allow(config).to receive(:redis_config).and_return(
        REDIS_CONFIG
      )
      allow(config).to receive(:logger).and_return(
        Logger.new(STDOUT).tap { |l| l.level = Logger::DEBUG }
      )
    end

    it "should get the lock" do
      trigger_lock_1 = described_class.new
      expect(trigger_lock_1.lock).to be true
      trigger_lock_2 = described_class.new
      expect(trigger_lock_2.lock).to be false
    end

    it "should set the lock expiration to be 61 seconds" do
      trigger_lock_1 = described_class.new
      Timecop.freeze(Time.new(1970, 1, 1)) do
        expect { trigger_lock_1.lock }.to change {
          TEST_REDIS.get(described_class::SCHEDULER_LOCK_KEY).to_f
        }.to(
          (Time.now + 60.seconds + 1.seconds).to_f
        )
      end
    end

    it "should refresh the lock expiration time when it is the owner" do
      trigger_lock_1 = described_class.new
      expect(trigger_lock_1.lock).to be true
      old_expiration_time = TEST_REDIS.get(described_class::SCHEDULER_LOCK_KEY).to_f
      sleep 1
      expect(trigger_lock_1.lock).to be true
      new_expiration_time = TEST_REDIS.get(described_class::SCHEDULER_LOCK_KEY).to_f
      expect(old_expiration_time < new_expiration_time).to be true

      trigger_lock_2 = described_class.new
      expect(trigger_lock_2.lock).to be false
      expect { trigger_lock_2.lock }.to_not change {
        TEST_REDIS.get(described_class::SCHEDULER_LOCK_KEY).to_f
      }
    end
  end
end
