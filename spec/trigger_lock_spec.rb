# encoding: utf-8
require "spec_helper"

RSpec.describe Sqeduler::TriggerLock do
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

    let(:trigger_lock_1) { described_class.new }
    let(:trigger_lock_2) { described_class.new }

    it "should get the lock" do
      lock_successes = [trigger_lock_1, trigger_lock_2].map do |trigger_lock|
        Thread.new { trigger_lock.lock }
      end.map(&:value)

      expect(lock_successes).to match_array([true, false])
    end

    it "should not be the owner if the lock has expired" do
      allow(trigger_lock_1).to receive(:expiration).and_return(1)
      expect(trigger_lock_1.lock).to be true
      expect(trigger_lock_1.locked?).to be true
      sleep 1
      expect(trigger_lock_1.locked?).to be false
    end

    it "should refresh the lock expiration time when it is the owner" do
      allow(trigger_lock_1).to receive(:expiration).and_return(1)
      expect(trigger_lock_1.lock).to be true
      sleep 1
      expect(trigger_lock_1.locked?).to be false
      expect(trigger_lock_1.refresh).to be true
    end

    it "should not refresh the lock when it is not owner" do
      threads = []
      threads << Thread.new do
        allow(trigger_lock_1).to receive(:expiration).and_return(1)
        trigger_lock_1.lock
        sleep 1.1
      end
      threads << Thread.new do
        sleep 1
        trigger_lock_2.lock
      end
      threads.each(&:join)
      expect(trigger_lock_2.locked?).to be(true)
      expect(trigger_lock_1.refresh).to be(false)
    end

    it "should release the lock when it is the owner" do
      expect(trigger_lock_1.lock).to be true
      expect(trigger_lock_1.unlock).to be true
      expect(trigger_lock_1.locked?).to be false
    end

    it "should not release the lock when it is the owner" do
      threads = []
      threads << Thread.new do
        allow(trigger_lock_1).to receive(:expiration).and_return(1)
        trigger_lock_1.lock
        sleep 1
      end
      threads << Thread.new do
        sleep 1
        trigger_lock_2.lock
      end
      threads.each(&:join)
      expect(trigger_lock_2.locked?).to be(true)
      expect(trigger_lock_1.unlock).to be(false)
    end
  end
end
