# frozen_string_literal: true
require 'companies_house/api_error'
require 'net/http'
require 'json'

module CompaniesHouse
  # This class connects to the Companies House API
  # at https://api.companieshouse.gov.uk
  class Client
    ENDPOINT = 'https://api.companieshouse.gov.uk'

    attr_reader :api_key, :endpoint

    def initialize(config)
      raise ArgumentError, 'Missing API key' unless config[:api_key]
      @api_key = config[:api_key]
      @endpoint = config[:endpoint] || ENDPOINT
      raise ArgumentError, 'HTTP is not supported' if URI(@endpoint).scheme != 'https'
    end

    def company(id)
      request(id)
    end

    def officers(id)
      request(id, '/officers')
    end

    private

    def request(company_id, extra_path = '')
      uri = URI.join(endpoint, 'company/', "#{company_id}#{extra_path}")
      req = Net::HTTP::Get.new(uri)
      req.basic_auth api_key, ''

      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        response = http.request req
        parse(response, company_id)
      end
    end

    def parse(response, company_id)
      case response.code
      when '200'
        return JSON[response.body]
      when '404'
        raise CompaniesHouse::APIError.new("Company #{company_id} not found", response)
      when '429'
        raise CompaniesHouse::APIError.new("Rate limit exceeded", response)
      else
        raise NotImplementedError
      end
    end
  end
end
