# frozen_string_literal: true

module CompaniesHouse
  # Raised when a request returned a 502
  class BadGatewayError < APIError
    def initialize(response = nil)
      super("Bad gateway error", response)
    end
  end
end
