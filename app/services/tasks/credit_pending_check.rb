module Tasks
  # spec §6.7 "Venduto non accreditato": "Vendite oltre 30 giorni:
  # un'attività credit_pending con il conteggio" - one Task for the whole
  # account (spec §4.15: "una sola attività per import, con i conteggi, non
  # un'attività per item"), opened/resolved automatically as the condition
  # appears/disappears.
  class CreditPendingCheck
    THRESHOLD = 30.days

    def initialize(account)
      @account = account
    end

    def call!
      count = overdue_orders.count

      if count.positive?
        Task.open_or_create!(kind: "credit_pending", subject: account, account: account, priority: "normal", metadata: { count: count })
      else
        Task.find_by(account: account, subject: account, kind: "credit_pending", status: %w[open snoozed])&.resolve!
      end
    end

    private

    attr_reader :account

    def overdue_orders
      account.sale_orders.where(status: %w[paid shipped delivered], credited_at: nil).where(sold_at: ...THRESHOLD.ago)
    end
  end
end
