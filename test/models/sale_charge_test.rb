require "test_helper"

class SaleChargeTest < ActiveSupport::TestCase
  setup do
    @sale = accounts(:acme).sale_orders.create!(channel: channels(:acme_fair), currency: "EUR")
  end

  test "direction is derived from kind" do
    charge = @sale.sale_charges.create!(kind: "shipping_charged", amount_cents: 300)
    assert_equal "income", charge.direction
    assert charge.income?

    fee = @sale.sale_charges.create!(kind: "platform_fee", amount_cents: 100)
    assert_equal "expense", fee.direction
    assert_not fee.income?
  end

  test "amount_cents cannot be negative" do
    charge = @sale.sale_charges.new(kind: "shipping_charged", amount_cents: -100)
    assert_not charge.valid?
  end
end
