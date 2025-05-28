# CompaniesHouse::Client

[![GH Actions](https://github.com/gocardless/companies-house-rest/actions/workflows/main.yml/badge.svg)](https://github.com/gocardless/companies-house-rest/actions)

This Gem implements an API client for the Companies House REST API. It can be
used to look up information about companies registered in the United Kingdom.
As of July 2016, this API is described by Companies House as a "beta service."
More information about this free API can be found
[on the Companies House API website](https://developer.companieshouse.gov.uk/api/docs/index.html).

To interact the older [CompaniesHouse XML-based API](http://xmlgw.companieshouse.gov.uk/),
see the gem [companies-house-gateway](https://github.com/gocardless/companies-house-gateway-ruby).
(Monthly subscription [fees](http://xmlgw.companieshouse.gov.uk/CHDpriceList.shtml), and other fees, may apply.)

Quick start:

- Register an account via the `Sign In / Register` link
  [on the CompaniesHouse Developers website](https://developer.companieshouse.gov.uk/api/docs/)
- Register an API key at [Your Applications](https://developer.companieshouse.gov.uk/developer/applications)
- Put your API key in an environment variable (not in your code):

```shell
export COMPANIES_HOUSE_API_KEY=YOUR_API_KEY_HERE
```

- Install `companies-house-rest` through [RubyGems](https://rubygems.org/gems/companies-house-rest)
- Create and use a client:

```ruby
require 'companies_house/client'
client = CompaniesHouse::Client.new(api_key: ENV['COMPANIES_HOUSE_API_KEY'])
profile = client.company('07495895')
```

## Overview

This gem is meant to provide a simple synchronous API to look up company profile
information and company officers. The data returned is parsed JSON.

This gem provides information on companies by their Companies House company
number. This "company number" is actually a string and should be treated as such.
The string may consist solely of digits (including leading 0s) or begin with
alphabetic characters such as `NI` or `SC`.

## Authentication

Using the Companies House REST API requires you to register an account
[on the CompaniesHouse Developers website](https://developer.companieshouse.gov.uk/api/docs/)
and [configure an API key](https://developer.companieshouse.gov.uk/developer/applications).
Developers should read
[the Companies House developer guidelines](https://developer.companieshouse.gov.uk/api/docs/index/gettingStarted/developerGuidelines.html)
before using this API, and will note that these guidelines contain several
instructions regarding API keys:

- Do not embed API keys in your code
- Do not store API keys in your source tree
- Restrict API key use by IP address and domain
- **Regenerate your API keys regularly**
- Delete API keys when no longer required

## Client Initialization

All requests to the API are made through a client object:

```ruby
require 'companies_house/client'
client = CompaniesHouse::Client.new(config)
```

The client is configured by passing a hash to the constructor. The supported keys for this
hash are:

| Key                | Description                                                                        |
| ------------------ | ---------------------------------------------------------------------------------- |
| `:api_key`         | Required. The API key received after registration.                                 |
| `:endpoint`        | Optional. Specifies the base URI for the API (e.g. if using a self-hosted version) |
| `:instrumentation` | Optional. Instruments the request/response (see Instrumentation for details)       |

## Instrumentation

By default, no instrumentation is being applied.
If you are using Rails or the `ActiveSupport` gem, instrumentation will happen automatically via ![ActiveSupport::Notifications](https://api.rubyonrails.org/classes/ActiveSupport/Notifications.html)

## Requests

Once a client has been initialised, requests can be made to the API.
Details of the available fields in the response are in the Companies House
[documentation](https://developer.companieshouse.gov.uk/api/docs/index.html).
The endpoints currently implemented by the gem are:

| Client Method                                                                      | Endpoint                                | Description                                               |
| ---------------------------------------------------------------------------------- | --------------------------------------- | --------------------------------------------------------- |
| `.company(company_number)`                                                         | `GET /company/:company_number`          | Retrieves a company profile.                              |
| `.officers(company_number)`                                                        | `GET /company/:company_number/officers` | Retrieves a list of company officers.                     |
| `.company_search(query, items_per_page: nil, start_index: nil, restrictions: nil)` | `GET /search/companies`                 | Retrieves a list of companies that match the given query. |

### .company

This method implements the [readCompanyProfile](https://developer.companieshouse.gov.uk/api/docs/company/company_number/readCompanyProfile.html)
API and returns the full [companyProfile](https://developer.companieshouse.gov.uk/api/docs/company/company_number/companyProfile-resource.html)
resource.

### .officers

This method implements the [officersList](https://developer.companieshouse.gov.uk/api/docs/company/company_number/officers/officerList.html)
API. It will make one or more requests against this API, as necessary, to obtain
the full list of company officers. It returns only the values under the `items`
key from the
[officerList](https://developer.companieshouse.gov.uk/api/docs/company/company_number/officers/officerList-resource.html)
resource(s) which it reads.

### .company_search

This method implements the [searchCompanies](https://developer.companieshouse.gov.uk/api/docs/search/companies/companysearch.html)
API and returns the list of [companySearch](https://developer.companieshouse.gov.uk/api/docs/search-overview/CompanySearch-resource.html)
resources that match the given query. The `items_per_page`, `start_index` and `restrictions` parameters are optional.

### .filing_history_list

This method implements the [filingHistoryList](https://developer.companieshouse.gov.uk/api/docs/company/company_number/filing-history/getFilingHistoryList.html) API and returns the full [filingHistoryList](https://developer.companieshouse.gov.uk/api/docs/company/company_number/filing-history/filingHistoryList-resource.html) resource.

### .filing_history_item

This method implements the [filingHistoryItem](https://developer.companieshouse.gov.uk/api/docs/company/company_number/filing-history/transaction_id/getFilingHistoryItem.html) API and returns the full
[filingHistoryItem](https://developer.companieshouse.gov.uk/api/docs/company/company_number/filing-history/filingHistoryItem-resource.html) resource.

### Other API Methods

While there are other resources exposed by the
[Companies House API](https://developer.companieshouse.gov.uk/api/docs/index.html),
this gem does not implement access to these resources at this time.

## Error Handling

If a request to the Companies House API encounters an HTTP status other than
`200 OK`, it will raise an instance of `CompaniesHouse::APIError` instead of
returning response data. The error will have the following fields:

| Field      | Description                                             |
| ---------- | ------------------------------------------------------- |
| `response` | The Net::HTTP response object from the failed API call. |
| `status`   | A string containing the response status code.           |

Certain API responses will raise an instance of a more specific subclass of
`CompaniesHouse::APIError`:

| Status | Error                                 | Description                                                                                                                  |
| ------ | ------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| 401    | `CompaniesHouse::AuthenticationError` | Authentication error (invalid API key)                                                                                       |
| 404    | `CompaniesHouse::NotFoundError`       | Not Found. (No record of the company is available.)                                                                          |
| 429    | `CompaniesHouse::RateLimitError`      | Application is being [rate limited](https://developer.companieshouse.gov.uk/api/docs/index/gettingStarted/rateLimiting.html) |

The client will not catch any other errors which may occur, such as
errors involving network connections (e.g. `Errno::ECONNRESET`).

## Development

This gem is configured for development using a `bundler` workflow.
Tests are written using RSpec, and Rubocop is used to provide linting.
Bug reports and pull requests are welcome on this project's
[GitHub repository](https://github.com/gocardless/companies-house-rest).

To get started:

```shell
bundle install --path vendor
```

To run all tests and Rubocop:

```shell
bundle exec rake
```
