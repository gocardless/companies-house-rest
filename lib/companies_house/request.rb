# frozen_string_literal: true
require 'companies_house/api_error'
require 'companies_house/not_found_error'
require 'companies_house/authentication_error'
require 'companies_house/rate_limit_error'

require 'virtus'
require 'uri'
require 'json'

require 'active_support/notifications'

module CompaniesHouse
  # This class manages individual requests.
  # Users of the CompaniesHouse gem should not instantiate this class
  # and should instead use CompaniesHouse::Client.
  class Request
    include Virtus.model
    # API-level attributes
    attribute :connection, Net::HTTP, required: true
    attribute :api_key, String, required: true
    attribute :endpoint, URI, required: true

    # Physical request attributes
    attribute :path, String, required: true
    attribute :query, Hash, required: true

    # Logical request attributes
    attribute :resource_type, Symbol, required: true
    attribute :company_id, String, required: true

    def initialize(args)
      super(args)

      @uri = URI.join(endpoint, path)
      @uri.query = URI.encode_www_form(query)

      @notification_payload = {
        method: :get,
        path: path,
        query: query
      }
    end

    def execute
      @started = Time.now.utc

      req = Net::HTTP::Get.new(@uri)
      req.basic_auth @api_key, ''

      response = connection.request req
      @notification_payload[:status] = response.code

      begin
        response_body = @notification_payload[:response] = parse(response, company_id)
      rescue => e
        @notification_payload[:error] = e
        raise e
      ensure
        publish_notification
      end

      response_body
    end

    private

    def publish_notification
      ActiveSupport::Notifications.publish(
        "companies_house.#{resource_type}",
        @started, Time.now.utc,
        SecureRandom.hex(10), @notification_payload
      )
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
