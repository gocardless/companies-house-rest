# frozen_string_literal: true

require "companies_house/request"
require "companies_house/instrumentation/null"
require "net/http"
require "securerandom"

if defined?(ActiveSupport)
  require_relative "./instrumentation/active_support"
end

module CompaniesHouse
  # This class provides an interface to the Companies House API
  # at https://api.companieshouse.gov.uk.
  # Specifically, it manages the connections and arranges requests.
  class Client
    ENDPOINT = "https://api.companieshouse.gov.uk"

    attr_reader :api_key, :endpoint, :instrumentation

    def initialize(config)
      raise ArgumentError, "Missing API key" unless config[:api_key]

      @api_key = config[:api_key]
      @endpoint = URI(config[:endpoint] || ENDPOINT)
      @open_timeout = config[:open_timeout] || 60
      @read_timeout = config[:read_timeout] || 60
      @instrumentation = config[:instrumentation] || Instrumentation::Null
      raise ArgumentError, "HTTP is not supported" if @endpoint.scheme != "https"
    end

    def end_connection
      @connection.finish if @connection&.started?
    end

    def company(id)
      request(:company, "company/#{id}", {}, make_transaction_id, id)
    end

    def officers(id)
      get_all_pages(:officers, "company/#{id}/officers", id)
    end

    def persons_with_significant_control(id, register_view: false)
      get_all_pages(
        :persons_with_significant_control,
        "company/#{id}/persons-with-significant-control",
        id,
        register_view: register_view,
      )
    end

    def company_search(query, items_per_page: nil, start_index: nil)
      request(
        :company_search,
        "search/companies",
        { q: query, items_per_page: items_per_page, start_index: start_index }.compact,
      )
    end

    def connection
      @connection ||= Net::HTTP.new(endpoint.host, endpoint.port).tap do |conn|
        conn.use_ssl = true
        conn.open_timeout = @open_timeout
        conn.read_timeout = @read_timeout
      end
    end

    private

    # Fetch and combine all pages of a paginated API call
    def get_all_pages(resource, path, id, query = {})
      items = []
      offset = 0
      xid = make_transaction_id

      loop do
        page = request(resource, path, query.merge(start_index: offset), xid, id)
        new_items = page["items"]
        total = page["total_results"] || new_items.count

        items += new_items
        offset += new_items.count

        break if items.count >= total
      end

      items
    end

    def make_transaction_id
      SecureRandom.hex(10)
    end

    def request(resource,
                path,
                params = {},
                transaction_id = make_transaction_id,
                resource_id = nil)
      Request.new(
        connection: connection,
        api_key: @api_key,
        endpoint: @endpoint,
        path: path,
        query: params,
        resource_type: resource,
        resource_id: resource_id,
        transaction_id: transaction_id,
        instrumentation: instrumentation,
      ).execute
    end
  end
end
