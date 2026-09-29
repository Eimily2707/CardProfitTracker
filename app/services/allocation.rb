# Largest-remainder allocation (spec §7.2): splits `total` cents across
# `weights` so every part is an integer and the parts always sum back to
# `total` exactly - no rounding drift, regardless of how many parts.
# Ties (equal fractional remainder) go to the lowest index, deterministically.
module Allocation
  def self.allocate(total, weights)
    return allocate(-total, weights).map { |part| -part } if total.negative?

    weights = Array.new(weights.size, 1) if weights.sum.zero?
    sum = weights.sum

    raw = weights.map { |w| Rational(total * w, sum) }
    parts = raw.map(&:floor)

    order = raw.each_with_index.sort_by { |r, i| [ -(r - r.floor), i ] }.map(&:last)
    order.first(total - parts.sum).each { |i| parts[i] += 1 }

    parts
  end
end
