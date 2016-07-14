# frozen_string_literal: true
require 'spec_helper'

describe CompaniesHouse::Client do
  let(:api_key) { 'el-psy-congroo' }
  let(:example_endpoint) { 'https://api.example.com:8000' }

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
      client = described_class.new(api_key: api_key, endpoint: example_endpoint)
      expect(client.endpoint).to eq example_endpoint
    end

    it 'demands an API key' do
      expect { described_class.new({}) }.to raise_error(ArgumentError)
    end
  end
end
