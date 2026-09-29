require "test_helper"

class PurchaseChargeTest < ActiveSupport::TestCase
  setup do
    @purchase = accounts(:acme).purchases.create!(channel: channels(:acme_fair), title: "Test", currency: "EUR")
  end

  test "a discount must be negative" do
    charge = @purchase.purchase_charges.new(kind: "discount", amount_cents: 100)
    assert_not charge.valid?

    charge.amount_cents = -100
    assert charge.valid?
  end

  test "a non-discount charge must not be negative" do
    charge = @purchase.purchase_charges.new(kind: "shipping", amount_cents: -100)
    assert_not charge.valid?

    charge.amount_cents = 100
    assert charge.valid?
  end
end
