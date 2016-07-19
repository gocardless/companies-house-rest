# frozen_string_literal: true
require 'spec_helper'

RSpec.describe CompaniesHouse::RegistrationNumber do
  shared_examples 'validates' do
    it 'is a valid number' do
      expect(described_class.valid?(number)).to be true
    end
  end

  shared_examples 'rejects' do
    it 'is an invalid number' do
      expect(described_class.valid?(number)).to be false
    end
  end

  context 'matches limited companies with a zero prefix' do
    let(:number) { '07592231' }
    it_behaves_like 'validates'
  end

  context 'matches limited companies without a zero prefix' do
    let(:number) { '7592231' }
    it_behaves_like 'validates'
  end

  context 'matches OC companies' do
    let(:number) { 'OC592231' }
    it_behaves_like 'validates'
  end

  context 'matches LP companies' do
    let(:number) { 'LP592231' }
    it_behaves_like 'validates'
  end

  context 'matches SC companies' do
    let(:number) { 'SC592231' }
    it_behaves_like 'validates'
  end

  context 'matches SO companies' do
    let(:number) { 'SO592231' }
    it_behaves_like 'validates'
  end

  context 'matches SL companies' do
    let(:number) { 'SL592231' }
    it_behaves_like 'validates'
  end

  context 'matches NI companies' do
    let(:number) { 'NI592231' }
    it_behaves_like 'validates'
  end

  context 'matches R companies' do
    let(:number) { 'R7592231' }
    it_behaves_like 'validates'
  end

  context 'matches NC companies' do
    let(:number) { 'NC592231' }
    it_behaves_like 'validates'
  end

  context 'matches NL companies' do
    let(:number) { 'NL592231' }
    it_behaves_like 'validates'
  end

  context 'rejects short numbers' do
    let(:number) { 'NI045' }
    it_behaves_like 'rejects'
  end

  context 'rejects long numbers' do
    let(:number) { 'LP874892738923789724' }
    it_behaves_like 'rejects'
  end

  context 'rejects invalid prefixes' do
    let(:number) { 'BC098765' }
    it_behaves_like 'rejects'
  end

  context 'rejects length 8, no zero' do
    let(:number) { '88887654' }
    it_behaves_like 'rejects'
  end
end
