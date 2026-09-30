module Cardtrader
  # Imports the account's seller orders from CardTrader into SaleOrder/
  # SaleLine (spec §8.3 "Ordine come venditore -> SaleOrder", §8.4 state
  # mapping). CardTrader Zero orders (via_cardtrader_zero) and the
  # request_for_cancel/lost states are deliberately not advanced - flagged
  # review_required instead (§8.5's hub-consolidation logic is deferred).
  #
  # Money fields in the CardTrader API (seller_total, seller_price, ...) are
  # assumed here to be {"cents" => Integer, "currency" => "EUR"} shaped -
  # this isn't nailed down in the reference docs we could verify against, so
  # confirm it against a live response before relying on this in production
  # (same caveat as CtBlueprint's fixed_properties in Tranche 2).
  class SyncOrdersService
    PAGE_LIMIT = 100

    def initialize(account, client: Client.new)
      @account = account
      @client = client
    end

    # US-2.3-style ranged/bulk import: pages through order_as: "seller"
    # until an empty page. Returns [created_count, updated_count, failures].
    def sync_all!(sync_run: nil)
      created = 0
      updated = 0
      failures = []

      page = 1
      loop do
        batch = client.orders(order_as: "seller", limit: PAGE_LIMIT, page: page)
        break if batch.blank?

        batch.each do |payload|
          was_new = upsert_order!(payload)
          was_new ? (created += 1) : (updated += 1)
          sync_run&.record_order!(created: was_new, updated: !was_new)
        rescue StandardError => e
          failures << "order #{payload['id']}: #{e.message}"
          sync_run&.record_failure!("order #{payload['id']}: #{e.message}")
        end

        break if batch.size < PAGE_LIMIT

        page += 1
      end

      [ created, updated, failures ]
    end

    # US-2.2-style single-order import (on-demand button).
    def sync_one!(external_order_id, sync_run: nil)
      payload = client.order(external_order_id)
      was_new = upsert_order!(payload)
      sync_run&.record_order!(created: was_new, updated: !was_new)
      was_new
    end

    private

    attr_reader :account, :client

    def upsert_order!(payload)
      sale_order = find_or_build_sale_order(payload)
      new_record = sale_order.new_record?

      sale_order.assign_attributes(
        external_order_code: payload["code"],
        external_transaction_code: payload["transaction_code"],
        via_cardtrader_zero: !!payload["via_cardtrader_zero"],
        presale: !!payload["presale"],
        buyer_ref: payload.dig("buyer", "username"),
        currency: money(payload["seller_total"])&.fetch(:currency, nil) || sale_order.currency || account.base_currency
      )
      sale_order.save!

      upsert_sale_lines!(sale_order, payload["order_items"] || [])
      sale_order.apply_external_state!(payload["state"]) if payload["state"].present?

      new_record
    end

    def find_or_build_sale_order(payload)
      channel = account.channels.find_by(system_key: "cardtrader") || account.channels.active.first!

      account.sale_orders.find_or_initialize_by(channel: channel, external_order_id: payload["id"].to_s) do |order|
        order.origin = "cardtrader_api"
        order.currency = money(payload["seller_total"])&.fetch(:currency, nil) || account.base_currency
      end
    end

    def upsert_sale_lines!(sale_order, order_items)
      order_items.each do |item|
        next if item["deleted_at"].present?

        line = sale_order.sale_lines.find_or_initialize_by(external_order_item_id: item["id"].to_s)
        line.description = item["name"]
        line.quantity = item["quantity"] || 1
        line.unit_price_cents = money(item["seller_price"])&.fetch(:cents, 0) || 0
        line.ct_blueprint = CtBlueprint.find_by(ct_id: item["blueprint_id"])

        if line.inventory_item.blank?
          candidate = match_inventory_item(sale_order.account, line.ct_blueprint)
          if candidate
            line.inventory_item = candidate
            line.match_method = "fifo"
          else
            sale_order.review_required = true
            sale_order.review_reasons = (sale_order.review_reasons + [ "line_#{line.external_order_item_id}_no_inventory_match" ]).uniq
          end
        end

        line.save!
      end
    end

    # spec US-5.2: user_data_field first (deferred, M14), then FIFO by
    # blueprint/condition/language/foil (item_identification, §7.9) - this
    # tranche matches by blueprint + oldest acquired_on only.
    def match_inventory_item(account, ct_blueprint)
      return nil if ct_blueprint.nil?

      account.inventory_items.in_stock.where(ct_blueprint: ct_blueprint).order(:acquired_on).first
    end

    def money(value)
      return nil if value.blank?

      { cents: value["cents"] || value["amount_cents"], currency: value["currency"] }
    end
  end
end
