# frozen_string_literal: true

module CompaniesHouse
  # Deals with validating company registration numbers.
  class RegistrationNumber
    VALID_PREFIXES = %w(OC LP SC SO SL NI R NC NL).freeze

    def self.valid?(number)
      company_number_patterns.any? do |pattern|
        number.match(pattern)
      end
    end

    def self.company_number_patterns
      limited_company = /^0?[0-9]{7}$/
      prefixed_patterns = VALID_PREFIXES.map do |pre|
        /^#{pre}[0-9]{#{8 - pre.length}}$/
      end
      [limited_company, *prefixed_patterns]
    end

    def self.sanitise(number)
      # Currently will only remove spaces from company numbers - could be extended in the
      # future to correct other kinds of error.
      number.delete(" ")
    end
  end
end
