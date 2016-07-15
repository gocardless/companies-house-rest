# frozen_string_literal: true

module CompaniesHouse
  # Specific error class for when an invalid API key is used to access the service
  class RateLimitError < APIError
    def initialize(response)
      super("Rate limit exceeded", response)
    end
  end
end
