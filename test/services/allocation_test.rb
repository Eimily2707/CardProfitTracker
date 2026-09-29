require "test_helper"

# spec §7.2: largest-remainder allocation - the parts must always sum back
# to the total exactly, to the cent, regardless of how the weights split.
class AllocationTest < ActiveSupport::TestCase
  test "splits equally with the classic 1000 in 3 example" do
    assert_equal [ 334, 333, 333 ], Allocation.allocate(1000, [ 1, 1, 1 ])
  end

  test "parts always sum back to the total, for a wide range of totals and weights" do
    [
      [ 100, [ 1, 1, 1 ] ],
      [ 101, [ 1, 1, 1 ] ],
      [ 1, [ 1, 1, 1 ] ],
      [ 0, [ 1, 1, 1 ] ],
      [ 9999, [ 3, 7, 1, 1 ] ],
      [ 12345, [ 1 ] ],
      [ 7, [ 5, 5 ] ]
    ].each do |total, weights|
      parts = Allocation.allocate(total, weights)
      assert_equal total, parts.sum, "#{total} over #{weights} summed to #{parts.sum}"
    end
  end

  test "weights proportionally, giving the remainder to the highest fractional remainder" do
    # 100 split 1:2:3 -> exact shares 16.67/33.33/50 -> remainder unit goes
    # to the largest fraction (here, a three-way tie broken by lowest index).
    assert_equal [ 17, 33, 50 ], Allocation.allocate(100, [ 1, 2, 3 ])
  end

  test "breaks remainder ties by the lowest index, deterministically" do
    assert_equal [ 1, 0, 0 ], Allocation.allocate(1, [ 1, 1, 1 ])
    assert_equal [ 2, 1, 1 ], Allocation.allocate(4, [ 1, 1, 1 ])
  end

  test "falls back to equal weights when every weight is zero" do
    assert_equal [ 334, 333, 333 ], Allocation.allocate(1000, [ 0, 0, 0 ])
  end

  test "negative totals allocate the absolute value and reapply the sign" do
    assert_equal [ -334, -333, -333 ], Allocation.allocate(-1000, [ 1, 1, 1 ])
  end

  test "a single weight receives the whole total" do
    assert_equal [ 1000 ], Allocation.allocate(1000, [ 1 ])
  end
end
