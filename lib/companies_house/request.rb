# frozen_string_literal: true

require "companies_house/api_error"
require "companies_house/not_found_error"
require "companies_house/authentication_error"
require "companies_house/rate_limit_error"
require "companies_house/timeout_error"
require "companies_house/bad_gateway_error"

require "net/http"
require "uri"
require "json"
require "dry-struct"

module CompaniesHouse
  # This class manages individual requests.
  # Users of the CompaniesHouse gem should not instantiate this class
  # and should instead use CompaniesHouse::Client.
  class Request < Dry::Struct
    # API-level attributes
    attribute :connection, Dry.Types.Instance(Net::HTTP)
    attribute :api_key, Dry.Types::String
    attribute :endpoint, Dry.Types.Instance(URI)

    # Physical request attributes
    attribute :path, Dry.Types::String
    attribute :query, Dry.Types::Hash

    # Logical request attributes
    attribute :resource_type, Dry.Types::Symbol
    attribute :resource_id, Dry.Types.Nominal(Integer)

    attribute :transaction_id, Dry.Types::String
    attribute :instrumentation, Dry.Types.Interface(:publish)

    def initialize(args)
      super(args)

      @uri = URI.join(endpoint, path)
      @uri.query = URI.encode_www_form(query)

      @notification_payload = {
        method: :get,
        path: path,
        query: query,
      }
    end

    def execute
      @started = Time.now.utc
      response = request_resource(@uri)
      @notification_payload[:status] = response.code

      begin
        @notification_payload[:response] = parse(response, resource_type, resource_id)
      rescue StandardError => e
        @notification_payload[:error] = e
        raise e
      ensure
        publish_notification
      end
    rescue Net::OpenTimeout, Net::ReadTimeout
      raise TimeoutError
    end

    private

    def request_resource(uri)
      req = Net::HTTP::Get.new(uri)
      req.basic_auth api_key, ""

      connection.request req
    end

    def publish_notification
      instrumentation.publish(
        "companies_house.#{resource_type}",
        @started,
        Time.now.utc,
        transaction_id,
        @notification_payload,
      )
    end

    def parse(response, resource_type, resource_id)
      case response.code
      when "200"
        JSON[response.body]
      when "401"
        raise CompaniesHouse::AuthenticationError, response
      when "404"
        raise CompaniesHouse::NotFoundError.new(resource_type, resource_id, response)
      when "429"
        raise CompaniesHouse::RateLimitError, response
      when "502"
        raise CompaniesHouse::BadGatewayError, response
      else
        raise CompaniesHouse::APIError.new("Unknown API response", response)
      end
    end
  end
end
