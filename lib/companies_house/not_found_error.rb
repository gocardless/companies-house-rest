# frozen_string_literal: true

module CompaniesHouse
  # Specific error class for when a resource cannot be found (for example, if the company
  # number given is invaid)
  class NotFoundError < APIError
    def initialize(resource = nil, company_id = nil, response = nil)
      super("#{resource || 'Unknown'} resource (company_id: #{company_id || 'nil'}) not found", response)
    end
  end
end
