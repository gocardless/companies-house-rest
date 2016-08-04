# frozen_string_literal: true
require 'companies_house/api_error'
require 'companies_house/not_found_error'
require 'companies_house/authentication_error'
require 'companies_house/rate_limit_error'

require 'active_support/notifications'
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

    def publish(*args)
      ActiveSupport::Notifications.publish(*args)
    end

    private

    # rubocop:disable Metrics/AbcSize
    def request(verb, company_id, extra_path = '', params = {})
      started = Time.now.utc

      rest_path = "company/#{company_id}#{extra_path}"
      uri = URI.join(endpoint, rest_path)
      uri.query = URI.encode_www_form(params)

      req = Net::HTTP::Get.new(uri)
      req.basic_auth api_key, ''

      notification_payload = {
        method: :get,
        path: rest_path,
        query: params
      }
      response = connection.request req
      notification_payload[:status] = response.code

      begin
        response_body = parse(response, company_id)
        notification_payload[:response] = response_body
      rescue => e
        notification_payload[:error] = e
        raise e
      ensure
        publish("companies_house.get.#{verb}", started, Time.now.utc,
                SecureRandom.hex(10), notification_payload)
      end
    end

    def parse(response, company_id)
      case response.code
      when '200'
        return JSON[response.body]
      when '401'
        raise CompaniesHouse::AuthenticationError, response
      when '404'
        raise CompaniesHouse::NotFoundError.new(company_id, response)
      when '429'
        raise CompaniesHouse::RateLimitError, response
      else
        raise CompaniesHouse::APIError.new("Unknown API response", response)
      end
    end
  end
end
