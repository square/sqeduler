# encoding: utf-8
require "spec_helper"

RSpec.describe Sqeduler::Config do
  describe "#initialize" do
    subject do
      described_class.new(options)
    end

    let(:options) do
      {
        :logger => double,
        :schedule_path => "/tmp/schedule.yaml",
        :exception_notifier => proc { |e| puts e },
        :redis_config => {
          :host => "localhost",
          :db => 1
        },
        :sync_pool_size => 1,
        :sync_pool_timeout => 2
      }.merge(extras)
    end

    let(:extras) { {} }

    describe "redis configs" do
      it "should set the redis_config" do
        expect(subject.redis_config).to eq(options[:redis_config])
      end

      it "creates a connection pool" do
        expect(subject.sync_pool).to be_kind_of(ConnectionPool)
      end

      context "no redis_config provided" do
        let(:extras) do
          { :redis_config => nil }
        end

        it "should raise ArgumentError" do
          expect { subject }.to raise_error(ArgumentError)
        end
      end

      context "no sync_pool_timeout provided" do
        let(:extras) do
          { :sync_pool_timeout => nil }
        end

        it "should not raise ArgumentError" do
          expect { subject }.to_not raise_error
        end

        it "should raise when calling the sync_pool" do
          expect { subject.sync_pool }.to raise_error(ArgumentError)
        end
      end

      context "no sync_pool_size provided" do
        let(:extras) do
          { :sync_pool_size => nil }
        end

        it "should not raise ArgumentError" do
          expect { subject }.to_not raise_error
        end

        it "should raise when calling the sync_pool" do
          expect { subject.sync_pool }.to raise_error(ArgumentError)
        end
      end
    end

    describe "schedule_path" do
      it "should set the schedule_path" do
        expect(subject.schedule_path).to eq(options[:schedule_path])
      end

      context "no config provided" do
        let(:extras) do
          { :schedule_path => nil }
        end

        it "should raise ArgumentError" do
          expect { subject }.to raise_error(ArgumentError)
        end
      end
    end

    describe "exception_notifier" do
      it "should set the exception_notifier" do
        expect(subject.exception_notifier).to eq(options[:exception_notifier])
      end

      context "no config provided" do
        let(:extras) do
          { :exception_notifier => nil }
        end

        it "should raise ArgumentError" do
          expect { subject }.to raise_error(ArgumentError)
        end
      end
    end

    describe "logger" do
      it "should set the logger" do
        expect(subject.logger).to eq(options[:logger])
      end

      context "no config provided" do
        let(:extras) do
          { :logger => nil }
        end

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
            expect(subject.logger).to eq(logger)
          end
        end
      end
    end
  end
end
