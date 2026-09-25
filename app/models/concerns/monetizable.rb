module Monetizable
  extend ActiveSupport::Concern

  class_methods do
    # Defines a virtual EUR-decimal accessor (e.g. :total_price) backed by an
    # integer `_cents` column (e.g. total_price_cents), so forms can accept
    # "12.50" while the database keeps storing 1250.
    def monetize(*attribute_names)
      attribute_names.each do |attribute_name|
        cents_column = :"#{attribute_name}_cents"

        define_method(attribute_name) do
          cents = read_attribute(cents_column)
          cents.nil? ? nil : (cents / 100.0)
        end

        define_method("#{attribute_name}=") do |value|
          write_attribute(cents_column, Monetizable.cents_from(value))
        end
      end
    end
  end

  def self.cents_from(value)
    return nil if value.blank?

    (BigDecimal(value.to_s) * 100).round
  rescue ArgumentError
    nil
  end
end
