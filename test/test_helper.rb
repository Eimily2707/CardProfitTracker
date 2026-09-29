ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"
require "webmock/minitest"

WebMock.disable_net_connect!(allow_localhost: true)

module ActiveSupport
  class TestCase
    # Parallel workers fork after a pg connection is already open in the
    # parent, which reliably hangs libpq in the forked children on this
    # machine. Running serially avoids it; the suite is small enough that
    # this costs virtually nothing in wall-clock time.
    parallelize(workers: 1)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Cardtrader::Client.new (used with no explicit token override by every
    # Cardtrader job/service) reads this to authenticate. Without it, every
    # call raises Client::AuthenticationError - which discard_on then
    # swallows silently, making a job look like it "succeeded" while doing
    # nothing. Individual tests can still override it to test the no-token case.
    setup do
      ENV["CARDTRADER_API_TOKEN"] = "test-token"
    end

    teardown do
      ENV.delete("CARDTRADER_API_TOKEN")
    end

    # Add more helper methods to be used by all tests here...
  end
end
