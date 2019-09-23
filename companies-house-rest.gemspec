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
  spec.required_ruby_version = ">= 2.5.5"

  spec.add_runtime_dependency "virtus", "~> 1.0", ">= 1.0.5"

  spec.add_development_dependency "activesupport", ">= 4.2", "< 7"
  spec.add_development_dependency "gc_ruboconfig", "~> 2.4"
  spec.add_development_dependency "rake", "~> 12.0"
  spec.add_development_dependency "rspec", "~> 3.5"
  spec.add_development_dependency "rspec_junit_formatter", "~> 0.4.1"
  spec.add_development_dependency "timecop", "~> 0.8"
  spec.add_development_dependency "webmock", "~> 3.0"
end
