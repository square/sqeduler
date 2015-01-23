# encoding: utf-8
module Sqeduler
  class LockValue
    def value
      @value ||= [hostname, process_id, thread_id].join(":")
    end

    private

    def hostname
      local_hostname = Socket.gethostname
      Socket.gethostbyname(local_hostname).first
    rescue
      local_hostname
    end

    def process_id
      Process.pid
    end

    def thread_id
      Thread.current.object_id
    end
  end
end
