# frozen_string_literal: true

module CompaniesHouse
  # Specific error class for when a company cannot be found (for example, if the company
  # number given is invaid)
  class NotFoundError < APIError
    def initialize(company_id, response)
      super("Company #{company_id} not found", response)
    end
  end
end
