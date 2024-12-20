# frozen_string_literal: true

require "spec_helper"
require "json"

describe CompaniesHouse::Client do
  before { WebMock.disable_net_connect! }

  shared_context "multiple pages" do
    # rubocop:disable RSpec/IndexedLet
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
    # rubocop:enable RSpec/IndexedLet
  end

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

    it "sets the Null instrumenter when ActiveSupport is not present" do
      client = described_class.new(api_key: "key")
      expect(client.instrumentation).to eq(Instrumentation::Null)
    end

    it "can set the ActiveSupport instrumenter if constant is defined" do
      require "active_support"

      class_double(ActiveSupport::Notifications).as_stubbed_const
      client = described_class.new(api_key: "key")
      expect(client.instrumentation).to eq(Instrumentation::ActiveSupport)
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
    subject(:response) { client.company(company_id) }

    include_context "test client"

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
    subject(:response) { client.officers(company_id) }

    include_context "test client"

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
      include_context "multiple pages"

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
          "companies_house.officers",
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
          "companies_house.officers",
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
    subject(:response) do
      client.persons_with_significant_control(company_id, register_view: register_view)
    end

    include_context "test client"

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
      include_context "multiple pages"

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

  describe "#persons_with_significant_control_statements" do
    subject(:response) do
      client.persons_with_significant_control_statements(company_id,
                                                         register_view: register_view)
    end

    include_context "test client"

    let(:rest_path) do
      "company/#{company_id}/persons-with-significant-control-statements" \
        "?register_view=#{register_view}"
    end
    let(:request_method) { "persons_with_significant_control_statements" }
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
      include_context "multiple pages"

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
          restrictions: restrictions,
        )
      end

      let(:rest_query) do
        {
          q: query,
          items_per_page: items_per_page,
          start_index: start_index,
          restrictions: restrictions,
        }
      end
      let(:items_per_page) { 5 }
      let(:start_index) { 3 }
      let(:restrictions) { "active-companies" }

      before do
        stub_request(
          :get,
          "#{example_endpoint}/#{rest_path}?items_per_page=#{items_per_page}\
&q=#{query}&start_index=#{start_index}&restrictions=#{restrictions}",
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

  describe "#filing_history_list" do
    subject(:response) do
      client.filing_history_list(company_id)
    end

    include_context "test client"

    before do
      stub_request(:get, "#{example_endpoint}/#{rest_path}").
        with(basic_auth: [api_key, ""]).
        to_return(body: '{"filing_history": "data"}', status: status)
    end

    let(:rest_path) do
      "company/#{company_id}/filing-history"
    end
    let(:request_method) { "filing_history_list" }

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
            query: { "start_index" => 0 },
          ).to_return(body: single_page, status: status)
      end

      it "returns items from the one, single page" do
        expect(response).to eq(%w[item1 item2])
      end
    end

    context "when results are spread across several pages" do
      include_context "multiple pages"

      before do
        stub_request(:get, "#{example_endpoint}/#{rest_path}").
          with(
            basic_auth: [api_key, ""],
            query: { "start_index" => 0 },
          ).
          to_return(body: page1, status: status)
        stub_request(:get, "#{example_endpoint}/#{rest_path}").
          with(
            basic_auth: [api_key, ""],
            query: { "start_index" => 1 },
          ).
          to_return(body: page2, status: status)
      end

      it "returns items from all pages" do
        expect(response).to eq(%w[item1 item2])
      end
    end
  end

  describe "#filing_history_item" do
    subject(:response) do
      client.filing_history_item(company_id, transaction_id)
    end

    include_context "test client"

    let(:request_method) { "filing_history_item" }
    let(:transaction_id) { "abcdef-12345" }
    let(:rest_path) { "company/#{company_id}/filing-history/#{transaction_id}" }
    let(:rest_query) { {} }

    before do
      stub_request(:get, "#{example_endpoint}/#{rest_path}").
        with(basic_auth: [api_key, ""]).
        to_return(body: '{"filing_history_item": "data"}', status: status)
    end

    context "against a functioning API" do
      let(:status) { 200 }

      it "returns a parsed JSON representation" do
        expect(response).to eq("filing_history_item" => "data")
      end

      it_behaves_like "sends one happy notification"
    end
  end

  describe "#persons_with_significant_control_corporate_entity_beneficial_owner" do
    subject(:response) { client.persons_with_significant_control_corporate_entity_beneficial_owner(company_id, psc_id) }

    include_context "test client"

    let(:psc_id) { "psc123" }
    let(:rest_path) do
      "company/#{company_id}/persons-with-significant-control/corporate-entity-beneficial-owner/#{psc_id}"
    end
    let(:request_method) { "persons_with_significant_control_corporate_entity_beneficial_owner" }
    let(:rest_query) { {} }

    before do
      stub_request(:get, "#{example_endpoint}/#{rest_path}").
        with(basic_auth: [api_key, ""]).
        to_return(body: '{"psc": "data"}', status: status)
    end

    context "against a functioning API" do
      let(:status) { 200 }

      it "returns a parsed JSON representation" do
        expect(response).to eq("psc" => "data")
      end

      it_behaves_like "sends one happy notification"
    end
  end

  describe "#persons_with_significant_control_corporate_entity" do
    subject(:response) { client.persons_with_significant_control_corporate_entity(company_id, psc_id) }

    include_context "test client"

    let(:psc_id) { "psc123" }
    let(:rest_path) { "company/#{company_id}/persons-with-significant-control/corporate-entity/#{psc_id}" }
    let(:request_method) { "persons_with_significant_control_corporate_entity" }
    let(:rest_query) { {} }

    before do
      stub_request(:get, "#{example_endpoint}/#{rest_path}").
        with(basic_auth: [api_key, ""]).
        to_return(body: '{"psc": "data"}', status: status)
    end

    context "against a functioning API" do
      let(:status) { 200 }

      it "returns a parsed JSON representation" do
        expect(response).to eq("psc" => "data")
      end

      it_behaves_like "sends one happy notification"
    end
  end

  describe "#persons_with_significant_control_individual_beneficial_owner" do
    subject(:response) { client.persons_with_significant_control_individual_beneficial_owner(company_id, psc_id) }

    include_context "test client"

    let(:psc_id) { "psc123" }
    let(:rest_path) { "company/#{company_id}/persons-with-significant-control/individual-beneficial-owner/#{psc_id}" }
    let(:request_method) { "persons_with_significant_control_individual_beneficial_owner" }
    let(:rest_query) { {} }

    before do
      stub_request(:get, "#{example_endpoint}/#{rest_path}").
        with(basic_auth: [api_key, ""]).
        to_return(body: '{"psc": "data"}', status: status)
    end

    context "against a functioning API" do
      let(:status) { 200 }

      it "returns a parsed JSON representation" do
        expect(response).to eq("psc" => "data")
      end

      it_behaves_like "sends one happy notification"
    end
  end

  describe "#persons_with_significant_control_individual" do
    subject(:response) { client.persons_with_significant_control_individual(company_id, psc_id) }

    include_context "test client"

    let(:psc_id) { "psc123" }
    let(:rest_path) { "company/#{company_id}/persons-with-significant-control/individual/#{psc_id}" }
    let(:request_method) { "persons_with_significant_control_individual" }
    let(:rest_query) { {} }

    before do
      stub_request(:get, "#{example_endpoint}/#{rest_path}").
        with(basic_auth: [api_key, ""]).
        to_return(body: '{"psc": "data"}', status: status)
    end

    context "against a functioning API" do
      let(:status) { 200 }

      it "returns a parsed JSON representation" do
        expect(response).to eq("psc" => "data")
      end

      it_behaves_like "sends one happy notification"
    end
  end

  describe "#persons_with_significant_control_legal_person_beneficial_owner" do
    subject(:response) { client.persons_with_significant_control_legal_person_beneficial_owner(company_id, psc_id) }

    include_context "test client"

    let(:psc_id) { "psc123" }
    let(:rest_path) { "company/#{company_id}/persons-with-significant-control/legal-person-beneficial-owner/#{psc_id}" }
    let(:request_method) { "persons_with_significant_control_legal_person_beneficial_owner" }
    let(:rest_query) { {} }

    before do
      stub_request(:get, "#{example_endpoint}/#{rest_path}").
        with(basic_auth: [api_key, ""]).
        to_return(body: '{"psc": "data"}', status: status)
    end

    context "against a functioning API" do
      let(:status) { 200 }

      it "returns a parsed JSON representation" do
        expect(response).to eq("psc" => "data")
      end

      it_behaves_like "sends one happy notification"
    end
  end

  describe "#persons_with_significant_control_legal_person" do
    subject(:response) { client.persons_with_significant_control_legal_person(company_id, psc_id) }

    include_context "test client"

    let(:psc_id) { "psc123" }
    let(:rest_path) { "company/#{company_id}/persons-with-significant-control/legal-person/#{psc_id}" }
    let(:request_method) { "persons_with_significant_control_legal_person" }
    let(:rest_query) { {} }

    before do
      stub_request(:get, "#{example_endpoint}/#{rest_path}").
        with(basic_auth: [api_key, ""]).
        to_return(body: '{"psc": "data"}', status: status)
    end

    context "against a functioning API" do
      let(:status) { 200 }

      it "returns a parsed JSON representation" do
        expect(response).to eq("psc" => "data")
      end

      it_behaves_like "sends one happy notification"
    end
  end

  describe "#persons_with_significant_control_super_secure_beneficial_owner" do
    subject(:response) do
      client.persons_with_significant_control_super_secure_beneficial_owner(company_id, super_secure_id)
    end

    include_context "test client"

    let(:super_secure_id) { "super123" }
    let(:rest_path) do
      "company/#{company_id}/persons-with-significant-control/super-secure-beneficial-owner/#{super_secure_id}"
    end
    let(:request_method) { "persons_with_significant_control_super_secure_beneficial_owner" }
    let(:rest_query) { {} }

    before do
      stub_request(:get, "#{example_endpoint}/#{rest_path}").
        with(basic_auth: [api_key, ""]).
        to_return(body: '{"psc": "data"}', status: status)
    end

    context "against a functioning API" do
      let(:status) { 200 }

      it "returns a parsed JSON representation" do
        expect(response).to eq("psc" => "data")
      end

      it_behaves_like "sends one happy notification"
    end
  end

  describe "#persons_with_significant_control_super_secure_person" do
    subject(:response) { client.persons_with_significant_control_super_secure_person(company_id, super_secure_id) }

    include_context "test client"

    let(:super_secure_id) { "super123" }
    let(:rest_path) { "company/#{company_id}/persons-with-significant-control/super-secure/#{super_secure_id}" }
    let(:request_method) { "persons_with_significant_control_super_secure_person" }
    let(:rest_query) { {} }

    before do
      stub_request(:get, "#{example_endpoint}/#{rest_path}").
        with(basic_auth: [api_key, ""]).
        to_return(body: '{"psc": "data"}', status: status)
    end

    context "against a functioning API" do
      let(:status) { 200 }

      it "returns a parsed JSON representation" do
        expect(response).to eq("psc" => "data")
      end

      it_behaves_like "sends one happy notification"
    end
  end

  describe "#persons_with_significant_control_statement" do
    subject(:response) { client.persons_with_significant_control_statement(company_id, statement_id) }

    include_context "test client"

    let(:statement_id) { "statement123" }
    let(:rest_path) { "company/#{company_id}/persons-with-significant-control-statements/#{statement_id}" }
    let(:request_method) { "persons_with_significant_control_statement" }
    let(:rest_query) { {} }

    before do
      stub_request(:get, "#{example_endpoint}/#{rest_path}").
        with(basic_auth: [api_key, ""]).
        to_return(body: '{"psc_statement": "data"}', status: status)
    end

    context "against a functioning API" do
      let(:status) { 200 }

      it "returns a parsed JSON representation" do
        expect(response).to eq("psc_statement" => "data")
      end

      it_behaves_like "sends one happy notification"
    end
  end
end
