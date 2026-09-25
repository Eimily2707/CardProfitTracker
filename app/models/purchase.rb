class Purchase < ApplicationRecord
  include Monetizable

  SOURCES = %w[CardTrader Cardmarket Fiera Privato].freeze
  PRODUCT_TYPES = { "Sealed Box" => "sealed_box", "Pack" => "pack", "Single" => "single" }.freeze

  monetize :total_price, :shipping_cost, :tax

  enum :intent_type, { crack_and_sell: "crack_and_sell", keep_sealed: "keep_sealed" },
       default: "crack_and_sell", validate: true

  # Transient, not persisted on purchases: only used to carry a CardTrader
  # blueprint selection (from the order import, or a manual search on the
  # "keep sealed" form) into the auto-created sealed InventoryItem below.
  attr_accessor :cardtrader_blueprint_id, :category_id, :blueprint_image_url

  # Declared before inventory_items: dependent callbacks run in declaration
  # order, and this one must destroy the sealed item (while purchase_id still
  # points here) before the has_many below nullifies it out from under it.
  has_one :sealed_inventory_item, -> { where(is_sealed_product: true) },
          class_name: "InventoryItem", inverse_of: :purchase, dependent: :destroy
  has_many :inventory_items, dependent: :nullify

  validates :name, presence: true
  validates :currency, presence: true
  validates :total_price_cents, :shipping_cost_cents, :tax_cents,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :cardtrader_order_id, uniqueness: true, allow_nil: true
  validate :sealed_item_not_already_sold, if: :switching_away_from_keep_sealed?

  after_save :sync_sealed_inventory_item

  def total_spent_cents
    total_price_cents.to_i + shipping_cost_cents.to_i + tax_cents.to_i
  end

  def allocated_cost_cents
    inventory_items.sum(:allocated_cost_cents)
  end

  def remaining_to_allocate_cents
    (total_price_cents.to_i + shipping_cost_cents.to_i) - allocated_cost_cents
  end

  private

  def switching_away_from_keep_sealed?
    intent_type_changed? && intent_type_was == "keep_sealed" && intent_type == "crack_and_sell"
  end

  def sealed_item_not_already_sold
    return unless sealed_inventory_item&.sale.present?

    errors.add(:intent_type, "non può passare a Spacchetta e Vendi: il prodotto sigillato risulta già venduto")
  end

  # Keeps the auto-managed "sealed box" InventoryItem in sync with this purchase:
  # creates/updates it while intent_type is keep_sealed, and removes it (unlocking
  # the unboxing form) as soon as the intent switches to crack_and_sell.
  def sync_sealed_inventory_item
    if keep_sealed?
      item = sealed_inventory_item || build_sealed_inventory_item
      item.assign_attributes(
        card_name: name,
        allocated_cost_cents: total_price_cents.to_i + shipping_cost_cents.to_i,
        category_id: category_id || item.category_id,
        cardtrader_blueprint_id: cardtrader_blueprint_id || item.cardtrader_blueprint_id,
        image_url: blueprint_image_url.presence || item.image_url
      )
      item.save!
    elsif saved_change_to_intent_type? && sealed_inventory_item.present?
      sealed_inventory_item.destroy!
    end
  ensure
    # `sealed_inventory_item` is a has_one association: once loaded it caches
    # its target, so without a reset a build/destroy above would leave this
    # same Purchase instance returning a stale (or now-destroyed) record.
    association(:sealed_inventory_item).reset
  end
end
