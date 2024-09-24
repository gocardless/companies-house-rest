# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "companies_house/version"

Gem::Specification.new do |spec|
  spec.name          = "companies-house-rest"
  spec.version       = CompaniesHouse::VERSION
  spec.authors       = ["GoCardless Engineering"]
  spec.email         = ["developers@gocardless.com"]
  spec.license       = "MIT"

  spec.summary       = "Look up UK company registration information"
  spec.description   = "Client for the Companies House REST API. Provides company " \
                       "profiles and officer lists."
  spec.homepage      = "https://github.com/gocardless/companies-house-rest"

  spec.files         = `git ls-files -z lib/ *.gemspec LICENSE README.md`.split("\x0")
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 3.0.2"

  spec.add_dependency "dry-struct", "~> 1"

  spec.metadata["rubygems_mfa_required"] = "true"
end
