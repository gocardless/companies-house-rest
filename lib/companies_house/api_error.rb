# frozen_string_literal: true

module CompaniesHouse
  # Represents any response from the API which is not a 200 OK
  class APIError < StandardError
    attr_reader :status, :response

    def initialize(msg, response)
      msg = "#{msg} - HTTP #{response.code}"
      super(msg)
      @response = response
      @status = response.code
    end
  end
end
