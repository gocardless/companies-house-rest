# frozen_string_literal: true

module CompaniesHouse
  # Raised when a request has timed out
  class TimeoutError < APIError
    def initialize(response = nil)
      super("Request timed out", response)
    end
  end
end
