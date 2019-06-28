# frozen_string_literal: true

require "active_support/notifications"

module Instrumentation
  class ActiveSupport
    def self.publish(*args)
      ::ActiveSupport::Notifications.publish(**args)
    end
  end
end
