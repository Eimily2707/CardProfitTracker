require "test_helper"

class SaleLineTest < ActiveSupport::TestCase
  setup do
    @sale = accounts(:acme).sale_orders.create!(channel: channels(:acme_fair), currency: "EUR")
  end

  test "quantity must be greater than zero" do
    line = @sale.sale_lines.new(description: "A", quantity: 0, unit_price_cents: 100)
    assert_not line.valid?
  end

  test "unit_price_cents cannot be negative" do
    line = @sale.sale_lines.new(description: "A", unit_price_cents: -100)
    assert_not line.valid?
  end
end
