# encoding: utf-8
require "spec_helper"
require "./spec/fixtures/fake_worker"

def verify_callback_occured(file_path, times = 1)
  expect(File).to exist(file_path)
  expect(File.read(file_path).length).to eq(times)
end

def verify_callback_skipped(file_path)
  expect(File).to_not exist(file_path)
end

def maybe_cleanup_file(file_path)
  File.delete(file_path) if File.exist?(file_path)
end

RSpec.describe Sqeduler::BaseWorker do
  before do
    config = double
    allow(Sqeduler::Service).to receive(:config).and_return(config)
    allow(config).to receive(:sync_pool).and_return(
      ConnectionPool.new(:timeout => 1, :size => 2) { Redis.new(REDIS_CONFIG) }
    )
    allow(config).to receive(:logger).and_return(
      Logger.new(STDOUT).tap { |l| l.level = Logger::DEBUG }
    )
    allow(Sqeduler::Service).to receive(:handle_exception)
  end

  after do
    maybe_cleanup_file(FakeWorker::JOB_RUN_PATH)
    maybe_cleanup_file(FakeWorker::JOB_SUCCESS_PATH)
    maybe_cleanup_file(FakeWorker::JOB_FAILURE_PATH)
    maybe_cleanup_file(FakeWorker::JOB_LOCK_FAILURE_PATH)
    maybe_cleanup_file(FakeWorker::JOB_BEFORE_START_PATH)
    maybe_cleanup_file(FakeWorker::SCHEDULE_COLLISION_PATH)
  end

  describe "locking" do
    context "synchronized workers" do
      before do
        FakeWorker.synchronize_jobs :one_at_a_time,
                                    :expiration => expiration.seconds,
                                    :timeout => timeout.seconds
      end

      let(:expiration) { work_time * 4 }
      let(:work_time) { 0.1 }

      subject do
        threads = []
        threads << Thread.new { FakeWorker.new.perform(work_time) }
        threads << Thread.new do
          sleep wait_time
          FakeWorker.new.perform(work_time)
        end
        threads.each(&:join)
      end

      context "overlapping schedule" do
        let(:wait_time) { 0 }

        context "timeout is less than work_time (too short)" do
          let(:timeout) { work_time / 2 }

          it "one worker should be blocked" do
            subject
            verify_callback_occured(FakeWorker::JOB_LOCK_FAILURE_PATH)
          end

          it "only one worker should run" do
            subject
            verify_callback_occured(FakeWorker::JOB_RUN_PATH)
          end

          it "no worker should fail" do
            subject
            verify_callback_occured(FakeWorker::JOB_SUCCESS_PATH, 2)
            verify_callback_skipped(FakeWorker::JOB_FAILURE_PATH)
          end

          it "all workers should have received before_start" do
            subject
            verify_callback_occured(FakeWorker::JOB_BEFORE_START_PATH, 2)
          end

          it "a schedule collision should not have occurred" do
            subject
            verify_callback_skipped(FakeWorker::SCHEDULE_COLLISION_PATH)
          end
        end

        context "timeout is greater than work_time" do
          let(:timeout) { work_time * 4 }

          it "no worker should be blocked" do
            subject
            verify_callback_skipped(FakeWorker::JOB_LOCK_FAILURE_PATH)
          end

          it "both workers should succeed" do
            subject
            verify_callback_occured(FakeWorker::JOB_SUCCESS_PATH, 2)
          end

          it "no worker should fail" do
            subject
            verify_callback_skipped(FakeWorker::JOB_FAILURE_PATH)
          end

          it "all workers should have received before_start" do
            subject
            verify_callback_occured(FakeWorker::JOB_BEFORE_START_PATH, 2)
          end

          it "a schedule collision should not have occurred" do
            subject
            verify_callback_skipped(FakeWorker::SCHEDULE_COLLISION_PATH)
          end

          context "expiration too short" do
            let(:expiration) { work_time / 2 }

            it "no worker should be blocked" do
              subject
              verify_callback_skipped(FakeWorker::JOB_LOCK_FAILURE_PATH)
            end

            it "all workers should run" do
              subject
              verify_callback_occured(FakeWorker::JOB_RUN_PATH, 2)
            end

            it "all workers should have received before_start" do
              subject
              verify_callback_occured(FakeWorker::JOB_BEFORE_START_PATH, 2)
            end

            it "no worker should fail" do
              subject
              verify_callback_occured(FakeWorker::JOB_SUCCESS_PATH, 2)
              verify_callback_skipped(FakeWorker::JOB_FAILURE_PATH)
            end

            it "a schedule collision should occur" do
              subject
              verify_callback_occured(FakeWorker::SCHEDULE_COLLISION_PATH, 2)
            end
          end
        end
      end

      context "non-overlapping schedule" do
        let(:wait_time) { work_time * 2 }

        context "timeout is less than work_time (too short)" do
          let(:timeout) { work_time }

          it "no workers should be blocked" do
            subject
            verify_callback_skipped(FakeWorker::JOB_LOCK_FAILURE_PATH)
          end

          it "all workers should run" do
            subject
            verify_callback_occured(FakeWorker::JOB_RUN_PATH, 2)
          end

          it "no worker should fail" do
            subject
            verify_callback_occured(FakeWorker::JOB_SUCCESS_PATH, 2)
            verify_callback_skipped(FakeWorker::JOB_FAILURE_PATH)
          end

          it "all workers should have received before_start" do
            subject
            verify_callback_occured(FakeWorker::JOB_BEFORE_START_PATH, 2)
          end

          it "a schedule collision should not have occurred" do
            subject
            verify_callback_skipped(FakeWorker::SCHEDULE_COLLISION_PATH)
          end
        end

        context "timeout is greater than work_time" do
          let(:timeout) { work_time * 2 }

          it "no worker should be blocked" do
            subject
            verify_callback_skipped(FakeWorker::JOB_LOCK_FAILURE_PATH)
          end

          it "both workers should succeed" do
            subject
            verify_callback_occured(FakeWorker::JOB_SUCCESS_PATH, 2)
          end

          it "no worker should fail" do
            subject
            verify_callback_skipped(FakeWorker::JOB_FAILURE_PATH)
          end

          it "all workers should have received before_start" do
            subject
            verify_callback_occured(FakeWorker::JOB_BEFORE_START_PATH, 2)
          end

          context "expiration too short" do
            let(:expiration) { work_time / 2 }

            it "no worker should be blocked" do
              subject
              verify_callback_skipped(FakeWorker::JOB_LOCK_FAILURE_PATH)
            end

            it "all workers should run" do
              subject
              verify_callback_occured(FakeWorker::JOB_RUN_PATH, 2)
            end

            it "all workers should have received before_start" do
              subject
              verify_callback_occured(FakeWorker::JOB_BEFORE_START_PATH, 2)
            end

            it "no worker should fail" do
              subject
              verify_callback_occured(FakeWorker::JOB_SUCCESS_PATH, 2)
              verify_callback_skipped(FakeWorker::JOB_FAILURE_PATH)
            end

            it "a schedule collision should occur" do
              subject
              verify_callback_occured(FakeWorker::SCHEDULE_COLLISION_PATH, 2)
            end
          end
        end
      end
    end
  end
end
