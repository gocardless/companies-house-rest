# frozen_string_literal: true
require 'spec_helper'
require 'webmock/rspec'
require 'json'

describe CompaniesHouse::Client do
  let(:api_key) { 'el-psy-congroo' }
  let(:example_endpoint) { 'https://api.example.com:8000' }
  let(:company_id) { '07495895' }
  let(:client) { described_class.new(api_key: api_key, endpoint: example_endpoint) }
  before { WebMock.disable_net_connect! }

  describe '#initialize' do
    describe 'with an API key' do
      let(:client) { described_class.new(args) }
      let(:args) { { api_key: api_key } }

      it 'sets the .api_key' do
        expect(client.api_key).to eq(api_key)
      end

      it 'sets a default endpoint' do
        expect(client.endpoint).to eq 'https://api.companieshouse.gov.uk'
      end
    end

    it 'accepts an alternate endpoint' do
      alt_client = described_class.new(api_key: api_key, endpoint: example_endpoint)
      expect(alt_client.endpoint).to eq example_endpoint
    end

    it 'rejects your insecure http endpoint' do
      expect do
        described_class.new(api_key: 'zz', endpoint: 'http://example.net')
      end.to raise_error(ArgumentError)
    end

    it 'demands an API key' do
      expect { described_class.new({}) }.to raise_error(ArgumentError)
    end
  end

  context 'against a functioning API' do
    describe '#company' do
      before do
        stub_request(:get, "#{example_endpoint}/company/#{company_id}").
          with(basic_auth: [api_key, '']).
          to_return(body: '{"company": "data"}', status: 200)
      end
      it 'should return a parsed JSON representation' do
        expect(client.company(company_id)).to eq('company' => 'data')
      end
    end

    describe '#officers' do
      context 'when all results are on a single page' do
        let(:single_page) do
          {
            items_per_page: 2,
            total_results: 2,
            start_index: 0,
            items: %w(item1 item2)
          }.to_json
        end
        before do
          stub_request(:get, "#{example_endpoint}/company/#{company_id}/officers").
            with(basic_auth: [api_key, ''], query: { "start_index" => 0 }).
            to_return(body: single_page, status: 200)
        end
        it 'should return items from the one, single page' do
          expect(client.officers(company_id)).to eq(%w(item1 item2))
        end
      end

      context 'when results are spread across several pages' do
        let(:page1) do
          {
            items_per_page: 1,
            total_results: 2,
            start_index: 0,
            items: ['item1']
          }.to_json
        end

        let(:page2) do
          {
            items_per_page: 1,
            total_results: 2,
            start_index: 1,
            items: ['item2']
          }.to_json
        end
        before do
          stub_request(:get, "#{example_endpoint}/company/#{company_id}/officers").
            with(basic_auth: [api_key, ''], query: { "start_index" => 0 }).
            to_return(body: page1, status: 200)
          stub_request(:get, "#{example_endpoint}/company/#{company_id}/officers").
            with(basic_auth: [api_key, ''], query: { "start_index" => 1 }).
            to_return(body: page2, status: 200)
        end
        it 'should return items from all pages' do
          expect(client.officers(company_id)).to eq(%w(item1 item2))
        end
      end
    end
  end

  context 'when the API returns an error' do
    before do
      stub_request(:get, "#{example_endpoint}/company/#{company_id}").
        with(basic_auth: [api_key, '']).
        to_return(status: status)
      stub_request(:get, "#{example_endpoint}/company/#{company_id}/officers").
        with(basic_auth: [api_key, ''], query: { 'start_index' => 0 }).
        to_return(status: status)
    end

    shared_examples 'an error response' do
      it 'should raise an APIError about the 404' do
        expect { request }.to raise_error do |error|
          expect(error).to be_a(CompaniesHouse::APIError)
          expect(error.status).to eq(status.to_s)
          expect(error.response).to be_a(Net::HTTPResponse)
          expect(error.message).to eq(message)
        end
      end
    end

    context '404' do
      let(:status) { 404 }
      let(:message) { "Company #{company_id} not found - HTTP 404" }

      describe '#company' do
        it_should_behave_like 'an error response' do
          let(:request) { client.company(company_id) }
        end
      end

      describe '#officers' do
        it_should_behave_like 'an error response' do
          let(:request) { client.officers(company_id) }
        end
      end
    end

    context '429' do
      let(:status) { 429 }
      let(:message) { "Rate limit exceeded - HTTP 429" }

      describe '#company' do
        it_should_behave_like 'an error response' do
          let(:request) { client.company(company_id) }
        end
      end

      describe '#officers' do
        it_should_behave_like 'an error response' do
          let(:request) { client.officers(company_id) }
        end
      end
    end

    context '401' do
      let(:status) { 401 }
      let(:message) { "Invalid API key - HTTP 401" }

      describe '#company' do
        it_should_behave_like 'an error response' do
          let(:request) { client.company(company_id) }
        end
      end

      describe '#officers' do
        it_should_behave_like 'an error response' do
          let(:request) { client.officers(company_id) }
        end
      end
    end

    context 'any other code' do
      let(:status) { 342 }
      let(:message) { "Unknown API response - HTTP 342" }

      describe '#company' do
        it_should_behave_like 'an error response' do
          let(:request) { client.company(company_id) }
        end
      end

      describe '#officers' do
        it_should_behave_like 'an error response' do
          let(:request) { client.officers(company_id) }
        end
      end
    end
  end
end
