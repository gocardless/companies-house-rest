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
      @endpoint = URI(config[:endpoint] || ENDPOINT)
      raise ArgumentError, 'HTTP is not supported' if @endpoint.scheme != 'https'
    end

    def company(id)
      request(id)
    end

    # The API endpoint for company officers is paginated, and not all of the officers may
    # be returned in the first request. We deal with this by collating all the pages of
    # results into one result set before returning them.
    def officers(id)
      items = []
      offset = 0

      loop do
        page = request(id, '/officers', start_index: offset)
        total = page['total_results']
        new_items = page['items']
        items += new_items
        offset += new_items.count

        break if items.count >= total
      end

      items
    end

    private

    def request(company_id, extra_path = '', params = {})
      uri = URI.join(endpoint, 'company/', "#{company_id}#{extra_path}")
      uri.query = URI.encode_www_form(params)

      req = Net::HTTP::Get.new(uri)
      req.basic_auth api_key, ''

      response = connection.request req
      parse(response, company_id)
    end

    def parse(response, company_id)
      case response.code
      when '200'
        return JSON[response.body]
      when '401'
        raise CompaniesHouse::APIError.new("Invalid API key", response)
      when '404'
        raise CompaniesHouse::APIError.new("Company #{company_id} not found", response)
      when '429'
        raise CompaniesHouse::APIError.new("Rate limit exceeded", response)
      else
        raise CompaniesHouse::APIError.new("Unknown API response", response)
      end
    end

    def connection
      @connection ||= Net::HTTP.new(endpoint.host, endpoint.port)
      @connection.use_ssl = true
      @connection
    end
  end
end
