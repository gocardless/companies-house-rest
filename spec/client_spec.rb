# frozen_string_literal: true
require 'spec_helper'
require 'webmock/rspec'

describe CompaniesHouse::Client do
  let(:api_key) { 'el-psy-congroo' }
  let(:example_endpoint) { 'https://api.example.com:8000' }
  let(:company_id) { '07495895' }
  let(:client) { described_class.new(api_key: api_key, endpoint: example_endpoint) }
  before { WebMock.disable_net_connect! }

  let(:success_headers) do
    {
      'Content-Type' => 'application/json',
      'Date' => 'Thu, 14 Jul 2016 09:20:10 GMT',
      'X-Ratelimit-Remain' => '598',
      'Pragma' => 'no-cache',
      'X-Ratelimit-Reset' => '1468488290',
      'Cache-Control' => 'no-store, no-cache, must-revalidate, post-check=0, pre-check=0',
      'X-Ratelimit-Limit' => '600',
      'Access-Control-Expose-Headers' => 'Location,www-authenticate'
    }
  end

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
    before do
      stub_request(:get, "#{example_endpoint}/company/#{company_id}").
        with(basic_auth: [api_key, '']).
        to_return(body: '{"company": "data"}', status: 200, headers: success_headers)
      stub_request(:get, "#{example_endpoint}/company/#{company_id}/officers").
        with(basic_auth: [api_key, '']).
        to_return(body: '{"officers": ["data"]}', status: 200, headers: success_headers)
    end

    describe '#company' do
      it 'should return a parsed JSON representation' do
        expect(client.company(company_id)).to eq('company' => 'data')
      end
    end

    describe '#officers' do
      it 'should return a parsed JSON representation' do
        expect(client.officers(company_id)).to eq('officers' => ['data'])
      end
    end
  end

  context 'when the API returns an error' do
    before do
      stub_request(:get, "#{example_endpoint}/company/#{company_id}").
        with(basic_auth: [api_key, '']).
        to_return(status: status)
      stub_request(:get, "#{example_endpoint}/company/#{company_id}/officers").
        with(basic_auth: [api_key, '']).
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
  end
end
