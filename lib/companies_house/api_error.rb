# frozen_string_literal: true

module CompaniesHouse
  # Represents any response from the API which is not a 200 OK
  class APIError < StandardError
    attr_reader :status, :response

    def initialize(msg, response = nil)
      if response
        msg = "#{msg} - HTTP #{response.code}"
        @status = response.code
      end

      super(msg)
      @response = response
    end
  end
end
