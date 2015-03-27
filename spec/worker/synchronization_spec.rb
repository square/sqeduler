require 'spec_helper'

RSpec.describe Sqeduler::Worker::Synchronization do
  describe '.synchronize' do
    before do
      stub_const(
        'ParentWorker',
        Class.new do
          prepend Sqeduler::Worker::Synchronization
          synchronize :one_at_a_time, expiration: 10, timeout: 1
        end
      )

      stub_const('ChildWorker', Class.new(ParentWorker))
    end

    it 'should preserve the synchronize attributes' do
      expect(ChildWorker.synchronize_jobs_mode).to eq(:one_at_a_time)
      expect(ChildWorker.synchronize_jobs_expiration).to eq(10)
      expect(ChildWorker.synchronize_jobs_timeout).to eq(1)
    end

    it 'should allow the child class to update the synchronize attributes' do
      ChildWorker.synchronize :one_at_a_time, expiration: 20, timeout: 2
      expect(ChildWorker.synchronize_jobs_mode).to eq(:one_at_a_time)
      expect(ChildWorker.synchronize_jobs_expiration).to eq(20)
      expect(ChildWorker.synchronize_jobs_timeout).to eq(2)
      expect(ParentWorker.synchronize_jobs_mode).to eq(:one_at_a_time)
      expect(ParentWorker.synchronize_jobs_expiration).to eq(10)
      expect(ParentWorker.synchronize_jobs_timeout).to eq(1)
    end
  end
end
