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

    it "supports setting open_timeout" do
      client = described_class.new(api_key: "key", open_timeout: 1)
      expect(client.connection.open_timeout).to eq(1)
    end

    it "supports setting read_timeout" do
      client = described_class.new(api_key: "key", read_timeout: 2)
      expect(client.connection.read_timeout).to eq(2)
    end
  end

  describe "#end_connection" do
    include_context "test client"

    it "does not throw an exception if not started" do
      allow(client.connection).to receive(:started?).
        and_return(false)

      expect { client.end_connection }.to_not raise_error
    end

    it "is idempotent" do
      expect do
        client.end_connection
        client.end_connection
      end.to_not raise_error
    end
  end

  describe "#company" do
    include_context "test client"

    subject(:response) { client.company(company_id) }

    let(:request_method) { "company" }
    let(:rest_path) { "company/#{company_id}" }
    let(:rest_query) { {} }

    before do
      stub_request(:get, "#{example_endpoint}/#{rest_path}").
        with(basic_auth: [api_key, ""]).
        to_return(body: '{"company": "data"}', status: status)
    end

    context "against a functioning API" do
      let(:status) { 200 }

      it "returns a parsed JSON representation" do
        expect(response).to eq("company" => "data")
      end

      it_behaves_like "sends one happy notification"
    end

    context "when the API returns an error" do
      it_behaves_like "an API that handles all errors"
    end
  end

  describe "#officers" do
    include_context "test client"

    subject(:response) { client.officers(company_id) }

    let(:rest_path) { "company/#{company_id}/officers" }
    let(:request_method) { "officers" }

    context "when all results are on a single page" do
      let(:single_page) do
        {
          items_per_page: 2,
          total_results: 2,
          start_index: 0,
          items: %w[item1 item2],
        }.to_json
      end

      before do
        stub_request(:get, "#{example_endpoint}/#{rest_path}").
          with(basic_auth: [api_key, ""], query: { "start_index" => 0 }).
          to_return(body: single_page, status: status)
      end

      it "returns items from the one, single page" do
        expect(response).to eq(%w[item1 item2])
      end

      it_behaves_like "sends one happy notification" do
        let(:rest_query) { { start_index: 0 } }
      end
    end

    context "when results are spread across several pages" do
      let(:page1) do
        {
          items_per_page: 1,
          total_results: 2,
          start_index: 0,
          items: ["item1"],
        }.to_json
      end

      let(:page2) do
        {
          items_per_page: 1,
          total_results: 2,
          start_index: 1,
          items: ["item2"],
        }.to_json
      end

      before do
        stub_request(:get, "#{example_endpoint}/#{rest_path}").
          with(basic_auth: [api_key, ""], query: { "start_index" => 0 }).
          to_return(body: page1, status: status)
        stub_request(:get, "#{example_endpoint}/#{rest_path}").
          with(basic_auth: [api_key, ""], query: { "start_index" => 1 }).
          to_return(body: page2, status: status)
      end

      it "returns items from all pages" do
        expect(response).to eq(%w[item1 item2])
      end

      # rubocop:disable RSpec/ExampleLength
      it "sends two notifications" do
        notifications = notifications_of do
          response
        end

        expect(notifications).to match(
          [have_attributes(
            name: "companies_house.officers",
            payload: {
              method: :get,
              path: rest_path,
              query: { start_index: 0 },
              response: JSON[page1],
              status: status.to_s,
            },
          ), have_attributes(
            name: "companies_house.officers",
            payload: {
              method: :get,
              path: rest_path,
              query: { start_index: 1 },
              response: JSON[page2],
              status: status.to_s,
            },
            # This should match the transaction ID of the first notification
            transaction_id: notifications[0].transaction_id,
          )],
        )
      end
      # rubocop:enable RSpec/ExampleLength
    end

    context "when the API returns an error" do
      before do
        stub_request(:get, "#{example_endpoint}/company/#{company_id}/officers").
          with(basic_auth: [api_key, ""], query: { "start_index" => 0 }).
          to_return(status: status)
      end

      it_behaves_like "an API that handles all errors" do
        let(:rest_query) { { start_index: 0 } }
      end
    end
  end

  describe "#persons_with_significant_control" do
    include_context "test client"

    subject(:response) do
      client.persons_with_significant_control(company_id, register_view: register_view)
    end

    let(:rest_path) do
      "company/#{company_id}/persons-with-significant-control" \
        "?register_view=#{register_view}"
    end
    let(:request_method) { "persons_with_significant_control" }
    let(:register_view) { true }

    context "when all results are on a single page" do
      let(:single_page) do
        {
          items_per_page: 2,
          total_results: 2,
          start_index: 0,
          items: %w[item1 item2],
        }.to_json
      end

      before do
        stub_request(:get, "#{example_endpoint}/#{rest_path}").
          with(
            basic_auth: [api_key, ""],
            query: { "start_index" => 0, register_view: register_view },
          ).to_return(body: single_page, status: status)
      end

      it "returns items from the one, single page" do
        expect(response).to eq(%w[item1 item2])
      end

      context "with register_view: false" do
        let(:register_view) { false }

        it "returns items from the one, single page" do
          expect(response).to eq(%w[item1 item2])
        end
      end
    end

    context "when results are spread across several pages" do
      let(:page1) do
        {
          items_per_page: 1,
          total_results: 2,
          start_index: 0,
          items: ["item1"],
        }.to_json
      end

      let(:page2) do
        {
          items_per_page: 1,
          total_results: 2,
          start_index: 1,
          items: ["item2"],
        }.to_json
      end

      before do
        stub_request(:get, "#{example_endpoint}/#{rest_path}").
          with(
            basic_auth: [api_key, ""],
            query: { "start_index" => 0, register_view: true },
          ).
          to_return(body: page1, status: status)
        stub_request(:get, "#{example_endpoint}/#{rest_path}").
          with(
            basic_auth: [api_key, ""],
            query: { "start_index" => 1, register_view: true },
          ).
          to_return(body: page2, status: status)
      end

      it "returns items from all pages" do
        expect(response).to eq(%w[item1 item2])
      end
    end
  end

  describe "#company_search" do
    include_context "test client"

    let(:request_method) { "company_search" }
    let(:rest_path) { "search/companies" }
    let(:query) { "020" }
    let(:company_id) { nil }

    context "using only mandatory parameter" do
      subject(:response) { client.company_search(query) }

      let(:rest_query) { { q: query } }

      before do
        stub_request(
          :get,
          "#{example_endpoint}/#{rest_path}?q=#{query}",
        ).
          with(basic_auth: [api_key, ""]).
          to_return(body: '{"companies": "data"}', status: status)
      end

      context "against a functioning API" do
        let(:status) { 200 }

        it "returns a parsed JSON representation" do
          expect(response).to eq("companies" => "data")
        end

        it_behaves_like "sends one happy notification"
      end

      context "when the API returns an error" do
        it_behaves_like "an API that handles all errors"
      end
    end

    context "providing all parameters" do
      subject(:response) do
        client.company_search(
          query,
          items_per_page: items_per_page,
          start_index: start_index,
        )
      end

      let(:rest_query) do
        {
          q: query,
          items_per_page: items_per_page,
          start_index: start_index,
        }
      end
      let(:items_per_page) { 5 }
      let(:start_index) { 3 }

      before do
        stub_request(
          :get,
          "#{example_endpoint}/#{rest_path}?items_per_page=#{items_per_page}\
&q=#{query}&start_index=#{start_index}",
        ).
          with(basic_auth: [api_key, ""]).
          to_return(body: '{"companies": "data"}', status: status)
      end

      context "against a functioning API" do
        let(:status) { 200 }

        it "returns a parsed JSON representation" do
          expect(response).to eq("companies" => "data")
        end

        it_behaves_like "sends one happy notification"
      end

      context "when the API returns an error" do
        it_behaves_like "an API that handles all errors"
      end
    end
  end
end
