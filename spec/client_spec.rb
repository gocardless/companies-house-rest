# frozen_string_literal: true

require "spec_helper"
require "json"

describe CompaniesHouse::Client do
  before { WebMock.disable_net_connect! }

  describe "#initialize" do
    include_context "test credentials"
    describe "with an API key" do
      let(:client) { described_class.new(args) }
      let(:args) { { api_key: api_key } }

      it "sets the .api_key" do
        expect(client.api_key).to eq(api_key)
      end

      it "sets a default endpoint" do
        expect(client.endpoint).to eq URI("https://api.companieshouse.gov.uk")
      end
    end

    it "accepts an alternate endpoint" do
      alt_client = described_class.new(api_key: api_key, endpoint: example_endpoint)
      expect(alt_client.endpoint).to eq example_endpoint
    end

    it "rejects your insecure http endpoint" do
      expect do
        described_class.new(api_key: "zz", endpoint: "http://example.net")
      end.to raise_error(ArgumentError)
    end

    it "demands an API key" do
      expect { described_class.new({}) }.to raise_error(ArgumentError)
    end
  end

  describe "#end_connection" do
    include_context "test client"

    it "should not throw an exception if not started" do
      allow(client.connection).to receive(:started?).
        and_return(false)

      expect { client.end_connection }.not_to raise_error
    end

    it "is idempotent" do
      expect do
        client.end_connection
        client.end_connection
      end.not_to raise_error
    end
  end
end
