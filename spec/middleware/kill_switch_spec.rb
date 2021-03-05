# frozen_string_literal: true

require "spec_helper"

RSpec.describe Sqeduler::Middleware::KillSwitch do
  before do
    Sqeduler::Service.config = Sqeduler::Config.new(
      redis_hash: REDIS_CONFIG,
      logger: Logger.new($stdout).tap { |l| l.level = Logger::DEBUG }
    )
  end

  describe "#call" do
    shared_examples_for "job is enqueued" do
      it "should enqueue the job" do
        expect do |b|
          described_class.new.call(worker_klass, nil, nil, nil, &b)
        end.to yield_control
      end
    end

    shared_examples_for "job is not enqueued" do
      it "should not enqueue the job" do
        expect do |b|
          described_class.new.call(worker_klass, nil, nil, nil, &b)
        end.to_not yield_control
      end
    end

    let(:worker_klass) { MyWorker }

    context "job does not prepend KillSwitch" do
      before do
        stub_const(
          "MyWorker",
          Class.new do
            include Sidekiq::Worker
            def perform; end
          end
        )
      end

      it_behaves_like "job is enqueued"

      context "worker_klass is a string" do
        let(:worker_klass) { "MyWorker" }

        it_behaves_like "job is enqueued"
      end
    end

    context "job prepends KillSwitch" do
      before do
        stub_const(
          "MyWorker",
          Class.new do
            include Sidekiq::Worker
            prepend Sqeduler::Worker::KillSwitch
            def perform; end
          end
        )
      end

      context "job is disabled" do
        before { MyWorker.disable }

        it_behaves_like "job is not enqueued"

        context "worker_klass is a string" do
          let(:worker_klass) { "MyWorker" }

          it_behaves_like "job is not enqueued"
        end
      end

      context "job is enabled" do
        before { MyWorker.enable }

        it_behaves_like "job is enqueued"

        context "worker_klass is a string" do
          let(:worker_klass) { "MyWorker" }

          it_behaves_like "job is enqueued"
        end
      end
    end
  end
end
