# frozen_string_literal: true

module Sqeduler
  module Worker
    # convenience module for including everything
    module Everything
      def self.included(mod)
        mod.prepend Sqeduler::Worker::Synchronization
        mod.prepend Sqeduler::Worker::KillSwitch
        # needs to be the last one
        mod.prepend Sqeduler::Worker::Callbacks
      end
    end
  end
end
