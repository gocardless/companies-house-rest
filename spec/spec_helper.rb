# frozen_string_literal: true

require "webmock/rspec"
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "companies_house/client"
require "timecop"

def notifications_of
  notifications = []
  subscriber = ActiveSupport::Notifications.subscribe do |*args|
    notifications << ActiveSupport::Notifications::Event.new(*args)
  end

  yield
  ActiveSupport::Notifications.unsubscribe(subscriber)
  notifications
end

shared_context "test credentials" do
  let(:api_key) { "el-psy-congroo" }
  let(:example_endpoint) { URI("https://api.example.com:8000") }
  let(:company_id) { "07495895" }
end

shared_context "test client" do
  include_context "test credentials"

  let(:client) { described_class.new(api_key: api_key, endpoint: example_endpoint) }
  let(:status) { 200 }
end

shared_examples "an error response" do
  # rubocop:disable RSpec/ExampleLength, RSpec/MultipleExpectations
  it "raises a specific APIError" do
    expect { response }.to raise_error do |error|
      expect(error).to be_a(error_class)
      expect(error.status).to eq(status.to_s)
      expect(error.response).to be_a(Net::HTTPResponse)
      expect(error.message).to eq(message)
    end
  end
  # rubocop:enable RSpec/ExampleLength, RSpec/MultipleExpectations

  it_behaves_like "sends one notification"
end

shared_examples "an API that handles all errors" do
  context "404" do
    let(:status) { 404 }
    let(:error_class) { CompaniesHouse::NotFoundError }
    let(:message) do
      "Resource not found - type `#{request_method}`, id `#{company_id || 'nil'}` \
- HTTP 404"
    end

    it_behaves_like "an error response"
  end

  context "429" do
    let(:status) { 429 }
    let(:message) { "Rate limit exceeded - HTTP 429" }
    let(:error_class) { CompaniesHouse::RateLimitError }

    it_behaves_like "an error response"
  end

  context "401" do
    let(:status) { 401 }
    let(:message) { "Invalid API key - HTTP 401" }
    let(:error_class) { CompaniesHouse::AuthenticationError }

    it_behaves_like "an error response"
  end

  context "502" do
    let(:status) { 502 }
    let(:message) { "Bad gateway error - HTTP 502" }
    let(:error_class) { CompaniesHouse::BadGatewayError }

    it_behaves_like "an error response"
  end

  context "any other code" do
    let(:status) { 342 }
    let(:message) { "Unknown API response - HTTP 342" }
    let(:error_class) { CompaniesHouse::APIError }

    it_behaves_like "an error response"
  end
end

shared_examples "sends one happy notification" do
  it_behaves_like "sends one notification" do
    let(:error_class) { nil }
  end
end

shared_examples "sends one notification" do
  let(:time) { Time.now.utc }

  # rubocop:disable RSpec/ExampleLength
  it "records to ActiveSupport" do
    i = 0
    allow(SecureRandom).to receive(:hex).with(10) do
      i += 1
      sprintf("RANDOM%04d", i)
    end

    recorded_notifications = notifications_of do
      Timecop.freeze(time) do
        response
      rescue StandardError
        ""
      end
    end

    expected_payload = {
      method: :get,
      path: rest_path,
      query: rest_query,
      status: status.to_s,
    }
    if error_class
      expected_payload[:error] = be_a(error_class)
    else
      expected_payload[:response] = be_truthy
    end

    expected_event = have_attributes(
      name: "companies_house.#{request_method}",
      time: time,
      end: time,
      payload: expected_payload,
      transaction_id: "RANDOM0001",
    )
    expect(recorded_notifications).to match([expected_event])
  end
  # rubocop:enable RSpec/ExampleLength
end
