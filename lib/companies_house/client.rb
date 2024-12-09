# frozen_string_literal: true

require "companies_house/request"
require "companies_house/instrumentation/null"
require "companies_house/instrumentation/active_support"
require "net/http"
require "securerandom"

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
      @instrumentation = configure_instrumentation(config[:instrumentation])
      raise ArgumentError, "HTTP is not supported" if @endpoint.scheme != "https"

      # Clear stale thread-local connection object if necessary - its lifetime should
      # match the lifetime of the client object
      Thread.current[:companies_house_client_connection] = nil
    end

    def end_connection
      return if Thread.current[:companies_house_client_connection].nil?
      return unless Thread.current[:companies_house_client_connection].started?

      Thread.current[:companies_house_client_connection].finish
      Thread.current[:companies_house_client_connection] = nil
    end

    def company(id)
      request(
        resource: :company,
        path: "company/#{id}",
        params: {},
        resource_id: id,
      )
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

    def persons_with_significant_control_statements(id, register_view: false)
      get_all_pages(
        :persons_with_significant_control_statements,
        "company/#{id}/persons-with-significant-control-statements",
        id,
        register_view: register_view,
      )
    end

    def filing_history_list(id)
      get_all_pages(:filing_history_list, "company/#{id}/filing-history", id)
    end

    def filing_history_item(id, transaction_id)
      request(
        resource: :filing_history_item,
        path: "company/#{id}/filing-history/#{transaction_id}",
      )
    end

    def company_search(query, items_per_page: nil, start_index: nil, restrictions: nil)
      request(
        resource: :company_search,
        path: "search/companies",
        params: {
          q: query, items_per_page: items_per_page, start_index: start_index,
          restrictions: restrictions
        }.compact,
      )
    end

    def connection
      Thread.current[:companies_house_client_connection] ||=
        Net::HTTP.new(endpoint.host, endpoint.port).tap do |conn|
          conn.use_ssl = true
          conn.open_timeout = @open_timeout
          conn.read_timeout = @read_timeout
        end
    end

    private

    def request(resource:,
                path:,
                params: {},
                transaction_id: make_transaction_id,
                resource_id: nil,
                headers: {})
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
        headers: headers,
      ).execute
    end

    # Fetch and combine all pages of a paginated API call
    def get_all_pages(resource, path, id, query = {})
      items = []
      offset = 0
      xid = make_transaction_id

      loop do
        page = request(
          resource: resource,
          path: path,
          params: query.merge(start_index: offset),
          transaction_id: xid,
          resource_id: id,
        )
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

    def configure_instrumentation(instrumentation)
      return instrumentation unless instrumentation.nil?

      if defined?(ActiveSupport::Notifications)
        Instrumentation::ActiveSupport
      else
        Instrumentation::Null
      end
    end
  end
end
