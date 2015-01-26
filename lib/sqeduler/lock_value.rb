# encoding: utf-8
module Sqeduler
  # A unique lock value for reserving a lock across multiple hosts
  class LockValue
    def value
      @value ||= [hostname, process_id, thread_id].join(":")
    end

    private

    def hostname
      Socket.gethostname
    end

    def process_id
      Process.pid
    end

    def thread_id
      Thread.current.object_id
    end
  end
end
