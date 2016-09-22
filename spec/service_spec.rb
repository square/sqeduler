# encoding: utf-8
require "spec_helper"

RSpec.describe Sqeduler::Service do
  let(:logger) do
    Logger.new(STDOUT).tap { |l| l.level = Logger::DEBUG }
  end

  before do
    described_class.instance_variables.each do |ivar|
      described_class.remove_instance_variable(ivar)
    end
  end

  describe ".start" do
    subject { described_class.start }

    context "no config provided" do
      it "should raise" do
        expect { subject }.to raise_error(RuntimeError, "No config provided")
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

      it "configures the server" do
        expect(Sidekiq).to receive(:configure_server)
        subject
      end

      it "configures the client" do
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

    context "with pool provided in config" do
      let(:original_pool) do
        ConnectionPool.new(:size => 10, :timeout => 0.1) do
          Redis::Namespace.new("sqeduler", :client => Redis.new(REDIS_CONFIG))
        end
      end

      before do
        described_class.config = Sqeduler::Config.new.tap do |config|
          config.redis_pool = original_pool
          config.logger = logger
        end
      end

      it "doesn't create a connection pool" do
        expect(subject.object_id).to eq(original_pool.object_id)
      end

      it "checks redis version" do
        allow_any_instance_of(Redis).to receive(:info).and_return(
          "redis_version" => "2.6.11"
        )
        expect { subject }.to raise_error(RuntimeError, "Must be using redis >= 2.6.12")
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
        expect { described_class.redis_pool }.to raise_error(RuntimeError, "Must be using redis >= 2.6.12")
      end
    end

    context "when provided redis_hash has strings as keys" do
      let(:expected_redis_config) do
        REDIS_CONFIG.merge(:namespace => "sqeduler")
      end

      before do
        described_class.config = Sqeduler::Config.new.tap do |config|
          config.redis_hash = REDIS_CONFIG.map { |k, v| [k.to_s, v] }.to_h
          config.logger = logger
        end
      end

      it "converts keys to symbols to create redis" do
        expect(::Sidekiq::RedisConnection).to receive(:create).with(expected_redis_config).and_call_original
        subject
      end
    end

    context "with namespace provided in redis_hash" do
      let(:redis_hash) { REDIS_CONFIG.merge(:namespace => "foo") }

      before do
        described_class.config = Sqeduler::Config.new.tap do |config|
          config.redis_hash = redis_hash
          config.logger = logger
        end
      end

      it "uses the provided namespace" do
        expect(::Sidekiq::RedisConnection).to receive(:create).with(redis_hash).and_call_original
        subject
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
        expect { subject }.to raise_error(ArgumentError, /^No logger provided/)
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
