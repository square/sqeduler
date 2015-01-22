# encoding: utf-8
require "spec_helper"

RSpec.describe Sqeduler::Service do
  describe ".start" do
    subject { described_class.start }
    context "no config provided" do
      it "should raise" do
        expect { subject }.to raise_error
      end
    end

    context "config provided" do
      let(:schedule_filepath) { "./spec/fixtures/schedule.yaml" }
      let(:logger) do
        Logger.new(STDOUT).tap { |l| l.level = Logger::DEBUG }
      end

      before do
        Sqeduler::Service.config = Sqeduler::Config.new(
          :redis_config => REDIS_CONFIG,
          :logger => logger,
          :schedule_path => schedule_filepath,
          :exception_notifier => proc { |e| puts e }
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

      it "starts the scheduler" do
        expect(Sidekiq).to receive(:"schedule=").with(YAML.load_file(schedule_filepath))
        subject
        expect(Sidekiq::Scheduler.rufus_scheduler_options).to have_key(:trigger_lock)
        expect(Sidekiq::Scheduler.rufus_scheduler_options[:trigger_lock]).to be_kind_of(
          Sqeduler::Scheduler::TriggerLock
        )
      end
    end
  end
end
