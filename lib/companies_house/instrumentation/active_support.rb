# frozen_string_literal: true

module Instrumentation
  class ActiveSupport
    def self.publish(*args)
      ::ActiveSupport::Notifications.publish(**args)
    end
  end
end
