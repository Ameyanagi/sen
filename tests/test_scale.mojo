from sen import LinearScale, linear_ticks
from std.collections import List
from std.testing import TestSuite, assert_equal, assert_raises, assert_true


def assert_tick_sequence(
    actual: Span[Float64, ...],
    expected: Span[Float64, ...],
    tolerance: Float64 = 0.0,
) raises:
    assert_equal(len(actual), len(expected))
    for index in range(len(actual)):
        assert_true(abs(actual[index] - expected[index]) <= tolerance)


def test_linear_scale_preserves_endpoints_and_maps_midpoint() raises:
    var scale = LinearScale(-2.0, 6.0, 10.0, 30.0)

    assert_true(scale.map(scale.domain_start()) == scale.range_start())
    assert_true(scale.map(scale.domain_end()) == scale.range_end())
    assert_true(scale.map(2.0) == 20.0)
    assert_true(scale == LinearScale(-2.0, 6.0, 10.0, 30.0))


def test_linear_scale_allows_reversed_domain_and_range() raises:
    var reversed_domain = LinearScale(10.0, 0.0, 0.0, 100.0)
    assert_true(reversed_domain.map(10.0) == 0.0)
    assert_true(reversed_domain.map(0.0) == 100.0)
    assert_true(reversed_domain.map(5.0) == 50.0)

    var reversed_range = LinearScale(0.0, 10.0, 100.0, 0.0)
    assert_true(reversed_range.map(0.0) == 100.0)
    assert_true(reversed_range.map(10.0) == 0.0)
    assert_true(reversed_range.map(2.5) == 75.0)


def test_linear_scale_round_trip_is_tight() raises:
    var scale = LinearScale(-7.0, 13.0, 420.0, -80.0)
    var values: List[Float64] = [-7.0, -3.25, 0.0, 8.5, 13.0]

    for index in range(len(values)):
        var restored = scale.invert(scale.map(values[index]))
        assert_true(abs(restored - values[index]) <= 1.0e-12)


def test_linear_scale_batch_matches_scalar_mapping() raises:
    var scale = LinearScale(-2.0, 2.0, 10.0, 18.0)
    var values: List[Float64] = [-2.0, -1.0, 0.0, 1.0, 2.0]
    var output: List[Float64] = [0.0, 0.0, 0.0, 0.0, 0.0]

    scale.map_all(values, output)

    for index in range(len(values)):
        assert_true(output[index] == scale.map(values[index]))

    var short_output: List[Float64] = [0.0]
    with assert_raises(contains="output buffer length must match input length"):
        scale.map_all(values, short_output)


def test_linear_scale_rejects_invalid_construction() raises:
    with assert_raises(contains="domain and range values must be finite"):
        _ = LinearScale(Float64("nan"), 1.0, 0.0, 1.0)
    with assert_raises(contains="domain and range values must be finite"):
        _ = LinearScale(0.0, Float64("inf"), 0.0, 1.0)
    with assert_raises(contains="domain and range values must be finite"):
        _ = LinearScale(0.0, 1.0, Float64("nan"), 1.0)
    with assert_raises(contains="domain and range values must be finite"):
        _ = LinearScale(0.0, 1.0, 0.0, Float64("inf"))
    with assert_raises(contains="domain must not be degenerate"):
        _ = LinearScale(2.0, 2.0, 0.0, 1.0)


def test_linear_scale_explicit_validation_reports_corrupted_storage() raises:
    var scale = LinearScale(0.0, 1.0, 10.0, 20.0)
    scale._domain_end = scale._domain_start
    with assert_raises(contains="domain must not be degenerate"):
        scale.validate()

    var nonfinite = LinearScale(0.0, 1.0, 10.0, 20.0)
    nonfinite._range_end = Float64("nan")
    with assert_raises(contains="domain and range values must be finite"):
        nonfinite.validate()


def test_degenerate_range_maps_but_cannot_be_inverted() raises:
    var scale = LinearScale(0.0, 1.0, 4.0, 4.0)
    assert_true(scale.map(0.5) == 4.0)
    with assert_raises(contains="degenerate linear scale range cannot be inverted"):
        _ = scale.invert(4.0)


def test_linear_ticks_unit_domain_fixture() raises:
    var actual = linear_ticks(0.0, 1.0)
    var expected: List[Float64] = [
        0.0,
        0.2,
        0.4,
        # Runtime Float64 multiplication, unlike exact literal folding,
        # yields the binary neighbor one ulp above 0.6.
        0.6000000000000001,
        0.8,
        1.0,
    ]
    assert_tick_sequence(actual, expected)


def test_linear_ticks_mixed_sign_fixture() raises:
    var actual = linear_ticks(-3.0, 7.0)
    var expected: List[Float64] = [-2.0, 0.0, 2.0, 4.0, 6.0]
    assert_tick_sequence(actual, expected)


def test_linear_ticks_tiny_domain_fixture() raises:
    var actual = linear_ticks(1.0e-6, 2.0e-6)
    var expected: List[Float64] = [
        5.0 * 2.0e-7,
        6.0 * 2.0e-7,
        7.0 * 2.0e-7,
        8.0 * 2.0e-7,
        9.0 * 2.0e-7,
        10.0 * 2.0e-7,
    ]
    assert_tick_sequence(actual, expected, tolerance=1.0e-18)


def test_linear_ticks_large_domain_fixture() raises:
    var actual = linear_ticks(0.0, 1.0e9)
    var expected: List[Float64] = [
        0.0,
        2.0e8,
        4.0e8,
        6.0e8,
        8.0e8,
        1.0e9,
    ]
    assert_tick_sequence(actual, expected)


def test_linear_ticks_normalize_reversed_domains_and_are_deterministic() raises:
    var first = linear_ticks(7.0, -3.0)
    var second = linear_ticks(7.0, -3.0)
    var expected: List[Float64] = [-2.0, 0.0, 2.0, 4.0, 6.0]

    assert_tick_sequence(first, expected)
    assert_tick_sequence(second, first)
    for index in range(1, len(first)):
        assert_true(first[index] > first[index - 1])
        assert_true(first[index] >= -3.0 and first[index] <= 7.0)


def test_linear_ticks_reject_invalid_inputs() raises:
    with assert_raises(contains="tick domain values must be finite"):
        _ = linear_ticks(Float64("nan"), 1.0)
    with assert_raises(contains="tick domain values must be finite"):
        _ = linear_ticks(0.0, Float64("inf"))
    with assert_raises(contains="tick domain must not be degenerate"):
        _ = linear_ticks(1.0, 1.0)
    with assert_raises(contains="tick target count must be at least two"):
        _ = linear_ticks(0.0, 1.0, target_count=1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
