# frozen_string_literal: true
require 'spec_helper'

describe CompaniesHouse::Client do
  before { WebMock.disable_net_connect! }
  include_context 'test client'

  describe '#company' do
    subject(:request) { client.company(company_id) }
    let(:request_verb) { 'company' }
    let(:rest_path) { "company/#{company_id}" }
    let(:rest_query) { {} }

    before do
      stub_request(:get, "#{example_endpoint}/#{rest_path}").
        with(basic_auth: [api_key, '']).
        to_return(body: '{"company": "data"}', status: status)
    end

    context 'against a functioning API' do
      let(:status) { 200 }
      it 'should return a parsed JSON representation' do
        expect(request).to eq('company' => 'data')
      end
    end

    context 'when the API returns an error' do
      it_behaves_like 'an API that handles all errors'
    end
  end
end
