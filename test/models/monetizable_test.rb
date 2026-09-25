require "test_helper"

class MonetizableTest < ActiveSupport::TestCase
  test "reads a cents column as a decimal euro value" do
    purchase = Purchase.new(total_price_cents: 1250)
    assert_equal 12.5, purchase.total_price
  end

  test "writes a decimal euro string into the cents column" do
    purchase = Purchase.new
    purchase.total_price = "12.50"
    assert_equal 1250, purchase.total_price_cents
  end

  test "writes a numeric euro value into the cents column" do
    purchase = Purchase.new
    purchase.total_price = 12.5
    assert_equal 1250, purchase.total_price_cents
  end

  test "rounds fractional cents" do
    purchase = Purchase.new
    purchase.total_price = "12.505"
    assert_equal 1251, purchase.total_price_cents
  end

  test "returns nil when the cents column is nil" do
    purchase = Purchase.new(total_price_cents: nil)
    assert_nil purchase.total_price
  end

  test "treats a blank string as nil cents" do
    purchase = Purchase.new
    purchase.total_price = ""
    assert_nil purchase.total_price_cents
  end

  test "treats nil as nil cents" do
    purchase = Purchase.new
    purchase.total_price = nil
    assert_nil purchase.total_price_cents
  end

  test "monetize can be applied to more than one attribute on the same model" do
    purchase = Purchase.new
    purchase.total_price = "100"
    purchase.shipping_cost = "10"
    purchase.tax = "2.5"

    assert_equal 10000, purchase.total_price_cents
    assert_equal 1000, purchase.shipping_cost_cents
    assert_equal 250, purchase.tax_cents
  end

  test "works for any including model, not just Purchase" do
    item = InventoryItem.new
    item.allocated_cost = "45.00"

    assert_equal 4500, item.allocated_cost_cents
    assert_equal 45.0, item.allocated_cost
  end
end
