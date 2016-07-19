# frozen_string_literal: true

module CompaniesHouse
  # Specific error class for when a company cannot be found
  class NotFoundError < APIError
    def initialize(company_id = nil, response = nil)
      super("Company #{company_id || 'nil'} not found", response)
    end
  end
end
