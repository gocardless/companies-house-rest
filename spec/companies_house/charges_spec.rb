# frozen_string_literal: true

require "spec_helper"
require "json"

describe CompaniesHouse::Client do
  before { WebMock.disable_net_connect! }

  describe "#charges" do
    include_context "test client"

    subject(:response) { client.charges(company_id) }

    let(:rest_path) { "company/#{company_id}/charges" }
    let(:request_method) { "charges" }

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

      # rubocop:disable RSpec/MultipleExpectations
      # rubocop:disable RSpec/ExampleLength
      it "sends two notifications" do
        expect(client.instrumentation).to receive(:publish).with(
          "companies_house.charges",
          kind_of(Time),
          kind_of(Time),
          kind_of(String),
          hash_including(
            method: :get,
            path: rest_path,
            query: { start_index: 0 },
            response: JSON[page1],
            status: status.to_s,
          ),
        ).and_call_original
        expect(client.instrumentation).to receive(:publish).with(
          "companies_house.charges",
          kind_of(Time),
          kind_of(Time),
          kind_of(String),
          hash_including(
            method: :get,
            path: rest_path,
            query: { start_index: 1 },
            response: JSON[page2],
            status: status.to_s,
          ),
        ).and_call_original

        response
      end
      # rubocop:enable RSpec/MultipleExpectations
      # rubocop:enable RSpec/ExampleLength
    end

    context "when the API returns an error" do
      before do
        stub_request(:get, "#{example_endpoint}/company/#{company_id}/charges").
          with(basic_auth: [api_key, ""], query: { "start_index" => 0 }).
          to_return(status: status)
      end

      it_behaves_like "an API that handles all errors" do
        let(:rest_query) { { start_index: 0 } }
      end
    end
  end
end
