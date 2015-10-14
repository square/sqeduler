# encoding: utf-8
require "spec_helper"

RSpec.describe Sqeduler::Service do
  let(:logger) do
    Logger.new(STDOUT).tap { |l| l.level = Logger::DEBUG }
  end

  describe ".start" do
    subject { described_class.start }

    context "no config provided" do
      it "should raise" do
        expect { subject }.to raise_error
      end
    end

    context "config provided" do
      let(:schedule_filepath) { Pathname.new("./spec/fixtures/schedule.yaml") }
      let(:server_receiver) { double }
      let(:client_receiver) { double }
      before do
        allow(server_receiver).to receive(:call)
        allow(client_receiver).to receive(:call)

        described_class.config = Sqeduler::Config.new(
          :redis_hash => REDIS_CONFIG,
          :logger => logger,
          :schedule_path => schedule_filepath,
          :on_server_start => proc { |config| server_receiver.call(config) },
          :on_client_start => proc { |config| client_receiver.call(config) }
        )
      end

      it "starts the server" do
        expect(Sidekiq).to receive(:configure_server)
        subject
      end

      it "starts the client" do
        expect(Sidekiq).to receive(:configure_client)
        subject
      end

      it "calls the appropriate on_server_start callbacks" do
        allow(Sidekiq).to receive(:server?).and_return(true)
        expect(server_receiver).to receive(:call)
        subject
      end

      it "calls the appropriate on_client_start callbacks" do
        expect(client_receiver).to receive(:call)
        subject
      end

      context "a schedule_path is provided" do
        it "starts the scheduler" do
          expect(Sidekiq).to receive(:"schedule=").with(
            "FakeWorker" => {
              "every" => "5s"
            }
          )
          subject
          expect(Sidekiq::Scheduler.rufus_scheduler_options).to have_key(:trigger_lock)
          expect(Sidekiq::Scheduler.rufus_scheduler_options[:trigger_lock]).to be_kind_of(
            Sqeduler::TriggerLock
          )
        end

        context "a schedule_path is a string" do
          let(:schedule_filepath) { "./spec/fixtures/schedule.yaml" }

          it "starts the scheduler" do
            expect(Sidekiq).to receive(:"schedule=").with(
              "FakeWorker" => {
                "every" => "5s"
              }
            )
            subject
            expect(Sidekiq::Scheduler.rufus_scheduler_options).to have_key(:trigger_lock)
            expect(Sidekiq::Scheduler.rufus_scheduler_options[:trigger_lock]).to be_kind_of(
              Sqeduler::TriggerLock
            )
          end
        end
      end

      context "a schedule_path is not provided" do
        let(:schedule_filepath) { nil }

        it "does not start the scheduler" do
          expect(Sidekiq).to_not receive(:"schedule=")
          subject
        end
      end
    end
  end

  describe ".redis_pool" do
    subject { described_class.redis_pool }

    before do
      described_class.config = Sqeduler::Config.new.tap do |config|
        config.redis_hash = REDIS_CONFIG
        config.logger = logger
      end
    end

    it "creates a connection pool" do
      expect(subject).to be_kind_of(ConnectionPool)
    end

    it "is memoized" do
      pool_1 = described_class.redis_pool
      pool_2 = described_class.redis_pool
      expect(pool_1.object_id).to eq(pool_2.object_id)
    end

    it "is not Sidekiq.redis" do
      described_class.start
      expect(Sidekiq.redis_pool.object_id).to_not eq(subject.object_id)
    end

    context "redis version is too low" do
      before do
        allow_any_instance_of(Redis).to receive(:info).and_return(
          "redis_version" => "2.6.11"
        )
        if described_class.instance_variable_defined?(:@redis_pool)
          described_class.remove_instance_variable(:@redis_pool)
        end

        if described_class.instance_variable_defined?(:@verified)
          described_class.remove_instance_variable(:@verified)
        end
      end

      it "should raise" do
        expect { described_class.redis_pool }.to raise_error
      end
    end
  end

  describe ".logger" do
    subject { described_class.logger }

    before do
      described_class.config = Sqeduler::Config.new.tap do |config|
        config.logger = logger
      end
    end

    context "provided in config" do
      it "return the config value" do
        expect(subject).to eq(logger)
      end
    end

    context "no config provided" do
      let(:logger) { nil }

      it "should raise ArgumentError" do
        expect { subject }.to raise_error(ArgumentError)
      end

      context "in a Rails app" do
        let(:logger) { double }
        before do
          rails = double
          stub_const("Rails", rails)
          allow(rails).to receive(:logger).and_return(logger)
        end

        it "should use the Rails logger" do
          expect(subject).to eq(logger)
        end
      end
    end
  end
end
