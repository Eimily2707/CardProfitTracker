module Cardtrader
  # Common base for every job that talks to the CardTrader API. Concrete
  # jobs declare their own queue_as (spec §9.1 defines several: ct_catalog,
  # ct_user_interactive, ct_webhooks, ct_user_bulk...), each with its own
  # concurrency group so one queue's traffic never blocks another's.
  class ApplicationJob < ::ApplicationJob
    # 429 and network blips are transient: back off and try again.
    retry_on Client::RateLimitError, Client::ConnectionError,
             wait: :polynomially_longer, attempts: 5

    # 401 (bad/missing token) and 404 (unknown resource) won't fix themselves on retry.
    discard_on Client::AuthenticationError, Client::NotFoundError
  end
end
