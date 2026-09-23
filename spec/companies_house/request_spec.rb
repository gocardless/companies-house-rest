# frozen_string_literal: true

require "spec_helper"

describe CompaniesHouse::Request do
  include_context "test credentials"

  # Client percent-encodes every interpolated identifier, so a dot segment should
  # never reach here. This guards the sink itself against a future resource method
  # that builds a path without escaping.
  def build(path)
    described_class.new(
      connection: Net::HTTP.new(example_endpoint.host, example_endpoint.port),
      api_key: api_key,
      endpoint: example_endpoint,
      path: path,
      query: {},
      headers: {},
      resource_type: :company,
      resource_id: nil,
      transaction_id: "0123456789abcdef",
      instrumentation: Instrumentation::Null,
    )
  end

  it "accepts a contained path" do
    expect(build("company/#{company_id}")).to be_a(described_class)
  end

  it "rejects a parent-directory segment" do
    expect { build("company/../search/companies") }.
      to raise_error(ArgumentError, /Invalid path/)
  end

  it "rejects a current-directory segment" do
    expect { build("company/./#{company_id}") }.
      to raise_error(ArgumentError, /Invalid path/)
  end
end
