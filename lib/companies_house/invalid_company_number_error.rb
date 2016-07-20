# frozen_string_literal: true

module CompaniesHouse
  # Specific error class for when a company number is invalid
  class InvalidCompanyNumberError < APIError
    def initialize(company_id = nil)
      super("Company number #{company_id || 'nil'} is invalid", nil)
    end
  end
end
