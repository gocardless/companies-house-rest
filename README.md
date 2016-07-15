# CompaniesHouse

This Gem implements an API client for the Companies House REST API. More information about
the API can be found
[here](https://developer.companieshouse.gov.uk/api/docs/index.html).

Currently for internal use at GoCardless, but could be open-sourced in the future as other
similar projects have been.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'companies-house-ruby'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install companies-house-ruby

## Usage

### Authentication

Using the Companies House REST API requires you to register an account
[here](https://beta.companieshouse.gov.uk). Once your account is confirmed you will be
given access to the API via an API key.

### Initialising a Client

All requests to the API are made through a client object:

```ruby
client = CompaniesHouse::Client.new(config)
```

The client is configured by passing a hash to the constructor. The supported keys for this
hash are:

| Key | Description |
| --- | ----------- |
| `:api_key` | Required. The API key received after registration. |
| `:endpoint` | Optional. Specifies the base URI for the API (e.g. if using a self-hosted version) |

### Making a Request

Once a client has been initialised, requests can be made to the API. The endpoints
currently implemented by the gem are:

| Endpoint | Client Method | Description |
| -------- | ------------- | ----------- |
| `GET /company/:id` | `client.company(id)` | Retrieves company details given a company number. |
| `GET /company/:id/officers` | `client.officers(id)` | Retrieves a list of company officers given the company number. |

Response data is given as a hash object directly obtained from the response JSON. Details
of the available fields in the response are in the Companies House
[documentation](https://developer.companieshouse.gov.uk/api/docs/index.html).

### Error Handling

If a request to the API returns with a status code other than `200 OK`, no response data
will be returned to the caller. Instead, an exception of type `CompaniesHouse::APIError`
will be raised. The additional fields available on an instance of this class are:

| Field | Description |
| ----- | ----------- |
| `response` | The Net::HTTP response object from the failed API call. |
| `status` | A string containing the response status code. |

## Development

This gem is configured for development using a `bundler` workflow.
Tests are written using RSpec, and Rubocop is used to provide linting.

To run all tests and Rubocop:

```shell
bundle exec rake
```

Bug reports and pull requests are welcome on GitHub at https://github.com/gocardless/companies-house-ruby.
