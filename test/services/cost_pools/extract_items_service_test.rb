require "test_helper"

module CostPools
  class ExtractItemsServiceTest < ActiveSupport::TestCase
    setup do
      @account = accounts(:acme)
      @sealed = @account.inventory_items.create!(
        kind: "sealed", name: "Booster Box", intent: "crack", status: "in_stock", cost_source: "manual",
        acquired_on: Date.current, public_ref: InventoryItem.generate_public_ref(@account),
        acquisition_cost_base_cents: 1000, cost_base_cents: 1000
      )
      @pool = OpenService.new(@sealed).call!
    end

    test "creates one item per unit of quantity, each tagged with the origin item and pool" do
      items = ExtractItemsService.new(@pool).call!(name: "Card", kind: "single", quantity: 3)

      assert_equal 3, items.size
      items.each do |item|
        assert_equal 1, item.quantity
        assert_equal @sealed, item.origin_item
        assert_equal @pool, item.cost_pool
        assert_equal "opening", item.acquisition_type
        assert_equal "in_stock", item.status
        assert_equal @sealed.acquired_on, item.acquired_on
      end
    end

    test "links a ct_blueprint and its game when given" do
      item = ExtractItemsService.new(@pool).call!(name: "Teferi", kind: "single", quantity: 1, ct_blueprint_id: ct_blueprints(:teferi).id).first

      assert_equal ct_blueprints(:teferi), item.ct_blueprint
      assert_equal ct_blueprints(:teferi).ct_game, item.ct_game
    end

    test "stores the reference value in the account's base currency" do
      item = ExtractItemsService.new(@pool).call!(name: "Card", kind: "single", quantity: 1, reference_value_cents: 500).first

      assert_equal 500, item.reference_value_cents
      assert_equal "EUR", item.reference_value_currency
    end

    test "raises when the pool is already closed" do
      ExtractItemsService.new(@pool).call!(name: "Card", kind: "single", quantity: 1)
      CloseService.new(@pool).call!(action: "distribute")

      assert_raises(ArgumentError) { ExtractItemsService.new(@pool).call!(name: "Another", kind: "single", quantity: 1) }
    end
  end
end
