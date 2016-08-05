# frozen_string_literal: true
require 'companies_house/request'
require 'net/http'

module CompaniesHouse
  # This class provides an interface to the Companies House API
  # at https://api.companieshouse.gov.uk
  # Specifically, it manages the connections and arranges requests.
  class Client
    ENDPOINT = 'https://api.companieshouse.gov.uk'

    attr_reader :api_key, :endpoint

    def initialize(config)
      raise ArgumentError, 'Missing API key' unless config[:api_key]
      @api_key = config[:api_key]
      @endpoint = URI(config[:endpoint] || ENDPOINT)
      raise ArgumentError, 'HTTP is not supported' if @endpoint.scheme != 'https'
    end

    def end_connection
      @connection.finish if @connection && @connection.started?
    end

    def company(id)
      request(:company, id)
    end

    # The API endpoint for company officers is paginated, and not all of the officers may
    # be returned in the first request. We deal with this by collating all the pages of
    # results into one result set before returning them.
    def officers(id)
      items = []
      offset = 0

      loop do
        page = request(:officers, id, '/officers', start_index: offset)
        new_items = page['items']
        total = page['total_results'] || new_items.count

        items += new_items
        offset += new_items.count

        break if items.count >= total
      end

      items
    end

    def connection
      @connection ||= Net::HTTP.new(endpoint.host, endpoint.port).tap do |conn|
        conn.use_ssl = true
      end
    end

    private

    def request(resource, company_id, extra_path = '', params = {})
      Request.new(
        connection: connection,
        api_key: @api_key,
        endpoint: @endpoint,

        path: "company/#{company_id}#{extra_path}",
        query: params,

        resource_type: resource,
        company_id: company_id
      ).execute
    end
  end
end
