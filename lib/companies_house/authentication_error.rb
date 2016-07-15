# frozen_string_literal: true

module CompaniesHouse
  # Specific error class for when an invalid API key is used to access the service
  class AuthenticationError < APIError
    def initialize(response)
      super("Invalid API key", response)
    end
  end
end
