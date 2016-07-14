# frozen_string_literal: true
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
      uri = URI.join(endpoint, 'company/', id)
      request(uri)
    end

    def officers(id)
      uri = URI.join(endpoint, 'company/', "#{id}/officers")
      request(uri)
    end

    private

    def request(uri)
      req = Net::HTTP::Get.new(uri)
      req.basic_auth api_key, ''

      resp = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.request req
      end

      JSON[resp.body]
    end
  end
end
