# frozen_string_literal: true

require "spec_helper"

RSpec.describe Sqeduler::LockMaintainer do
  let(:instance) { described_class.new }

  before do
    stub_const(
      "SyncExclusiveWorker",
      Class.new do
        include Sidekiq::Worker
        prepend Sqeduler::Worker::Synchronization
        synchronize :one_at_a_time, :expiration => 300, :timeout => 5

        def perform(*_args)
          yield
        end
      end
    )

    stub_const(
      "SyncShortWorker",
      Class.new do
        include Sidekiq::Worker
        prepend Sqeduler::Worker::Synchronization
        synchronize :one_at_a_time, :expiration => 5, :timeout => 5

        def perform
          raise "This shouldn't be called"
        end
      end
    )

    stub_const(
      "SyncWhateverWorker",
      Class.new do
        include Sidekiq::Worker
        prepend Sqeduler::Worker::Synchronization

        def perform
          raise "This shouldn't be called"
        end
      end
    )

    Sqeduler::Service.config = Sqeduler::Config.new(
      :redis_hash => REDIS_CONFIG,
      :logger => Logger.new("/dev/null"),
      :schedule_path => Pathname.new("./spec/fixtures/empty_schedule.yaml")
    )
  end

  context "#run" do
    let(:run) { instance.run }

    it "calls into the synchronizer" do
      expect(instance).to receive(:synchronize).at_least(1)

      run.join(1)
      run.terminate

      expect(instance.send(:redis_lock).locked?).to eq(false)
    end

    it "doesn't die on errors" do
      expect(instance).to receive(:synchronize).and_raise(StandardError, "Boom")

      run.join(1)
      expect(run.status).to_not be_falsy
      run.terminate
    end

    it "obeys the exclusive lock" do
      lock = Sqeduler::RedisLock.new("sqeduler-lock-maintainer", :expiration => 60, :timeout => 0)
      lock.lock

      expect(instance).to_not receive(:synchronize)

      run.join(1)
      run.terminate
    end
  end

  context "#synchronize" do
    subject(:sync) { instance.send(:synchronize) }

    let(:run_at) { Time.now.to_i }
    let(:job_args) { [1, { "a" => "b" }] }

    let(:workers) do
      [
        [
          "process-key",
          "worker-tid-1234",
          {
            "run_at" => run_at,
            "payload" => {
              "class" => "SyncExclusiveWorker",
              "args" => job_args
            }
          }
        ],
        [
          "process-key",
          "worker-tid-6789",
          {
            "run_at" => run_at,
            "payload" => {
              "class" => "SyncShortWorker",
              "args" => job_args
            }
          }
        ],
        [
          "process-key",
          "worker-tid-4321",
          {
            "run_at" => run_at,
            "payload" => {
              "class" => "SyncWhateverWorker",
              "args" => []
            }
          }
        ]
      ]
    end

    before { allow(instance).to receive(:workers).and_return(workers) }

    it "does nothing if the jobs just started" do
      expect(instance).to_not receive(:str_to_class)
      sync
    end

    context "when outside the run threshold" do
      let(:run_at) { (Time.now - described_class::RUN_INTERVAL - 5).to_i }

      let(:lock_key) { SyncExclusiveWorker.sync_lock_key(job_args) }

      it "refresh the lock" do
        SyncExclusiveWorker.new.perform(job_args) do
          Sqeduler::Service.redis_pool.with do |redis|
            # Change the lock timing to make sure ours works
            redis.expire(lock_key, 10)
            expect(redis.ttl(lock_key)).to eq(10)

            # Run the re-locker
            sync

            # Confirm it reset
            expect(redis.ttl(lock_key)).to eq(300)
          end
        end

        # Shouldn't be around once the job finished
        Sqeduler::Service.redis_pool.with do |redis|
          expect(redis.exists(lock_key)).to eq(0)
        end
      end
    end
  end

  context "#str_to_class" do
    it "only returns exclusive lock classes" do
      expect(instance.send(:str_to_class, "SyncExclusiveWorker")).to eq(SyncExclusiveWorker)
      expect(instance.send(:str_to_class, "SyncWhateverWorker")).to eq(false)
    end
  end
end
