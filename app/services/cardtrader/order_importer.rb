module Cardtrader
  # Builds an unsaved Purchase prefilled from a CardTrader order, so the user
  # only has to review it and pick crack_and_sell/keep_sealed before saving.
  #
  # We're always the buyer here, so pricing is read from the buyer-facing
  # fields (buyer_subtotal for the items, the shipping method's buyer_price).
  class OrderImporter
    def initialize(client: Client.new)
      @client = client
    end

    def recent_orders(limit: 20)
      client.orders(order_as: "buyer", limit: limit)
    end

    def build_purchase(order_id:)
      order = client.order(order_id)
      Purchase.new(attributes_from(order))
    end

    private

    attr_reader :client

    def attributes_from(order)
      items = Array(order["order_items"])
      subtotal = order["buyer_subtotal"] || {}
      shipping_price = order.dig("order_shipping_method", "buyer_price") || {}

      attributes = {
        cardtrader_order_id: order["id"],
        source: "CardTrader",
        via_cardtrader_zero: order["via_cardtrader_zero"] || false,
        purchase_date: parse_date(order["paid_at"] || items.first&.dig("created_at")),
        name: name_for(order, items),
        total_price_cents: subtotal["cents"],
        shipping_cost_cents: shipping_price["cents"],
        currency: subtotal["currency"] || "EUR"
      }

      attributes.merge!(sealed_blueprint_attributes(items)) if items.one?

      attributes
    end

    # Only prefills the sealed-box blueprint fields when the order has a single
    # line item - with several items there's no single "product" to attach.
    def sealed_blueprint_attributes(items)
      item = items.first

      {
        cardtrader_blueprint_id: item["blueprint_id"],
        category_id: item["category_id"],
        blueprint_image_url: CardtraderBlueprint.find_by(cardtrader_id: item["blueprint_id"])&.image_url
      }
    end

    def name_for(order, items)
      return items.first["name"] if items.one?

      "Ordine CardTrader ##{order['id']} (#{items.size} articoli)"
    end

    def parse_date(value)
      return nil if value.blank?

      Time.zone.parse(value.to_s)&.to_date
    rescue ArgumentError
      nil
    end
  end
end
