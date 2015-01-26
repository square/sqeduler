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
        :redis_hash => {
          :host => "localhost",
          :db => 1
        }
      }.merge(extras)
    end

    let(:extras) { {} }

    describe "redis_hash" do
      it "should set the redis_hash" do
        expect(subject.redis_hash).to eq(options[:redis_hash])
      end
    end

    describe "schedule_path" do
      it "should set the schedule_path" do
        expect(subject.schedule_path).to eq(options[:schedule_path])
      end
    end

    describe "logger" do
      it "should set the logger" do
        expect(subject.logger).to eq(options[:logger])
      end
    end
  end
end
