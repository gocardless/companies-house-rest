# frozen_string_literal: true

module CompaniesHouse
  # Specific error class for when a company cannot be found (for example, if the company
  # number given is invaid)
  class NotFoundError < APIError
    def initialize(resource_type, resource_id = nil, response = nil)
      super(
        "Resource not found - type `#{resource_type}`, id `#{resource_id || 'nil'}`",
        response,
      )
    end
  end
end
