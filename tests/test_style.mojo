from sen import LineStyle, MarkerStyle, SeriesStyle
from std.testing import (
    TestSuite,
    assert_false,
    assert_raises,
    assert_true,
)


def test_series_style_defaults_and_equality() raises:
    var style = SeriesStyle()

    assert_true(style.palette_slot() == -1)
    assert_true(style.line_style() == LineStyle.SOLID)
    assert_true(style.marker_style() == MarkerStyle.CIRCLE)
    assert_true(style.line_width() == 1.5)
    assert_true(style == SeriesStyle())
    assert_false(style == SeriesStyle(color_index=0))


def test_series_style_rejects_palette_indices_outside_fixed_cycle() raises:
    with assert_raises(contains="color index -1"):
        _ = SeriesStyle(color_index=-1)
    with assert_raises(contains="valid range 0..5"):
        _ = SeriesStyle(color_index=-1)
    with assert_raises(contains="color index 6"):
        _ = SeriesStyle(color_index=6)
    with assert_raises(contains="valid range 0..5"):
        _ = SeriesStyle(color_index=6)


def test_series_style_rejects_nonpositive_and_nonfinite_widths() raises:
    var style = SeriesStyle()
    with assert_raises(contains="got 0.0"):
        _ = style.with_width(0.0)
    with assert_raises(contains="got -1.0"):
        _ = style.with_width(-1.0)
    with assert_raises(contains="got inf"):
        _ = style.with_width(Float64("inf"))
    with assert_raises(contains="got nan"):
        _ = style.with_width(Float64("nan"))


def test_series_style_builders_modify_copies_only() raises:
    var original = SeriesStyle()
    var wide = original.with_width(2.5)
    var dashed = original.with_line_style(LineStyle.DASHED)
    var square = original.with_marker(MarkerStyle.SQUARE)

    assert_true(original.palette_slot() == -1)
    assert_true(original.line_style() == LineStyle.SOLID)
    assert_true(original.marker_style() == MarkerStyle.CIRCLE)
    assert_true(original.line_width() == 1.5)
    assert_true(wide.line_width() == 2.5)
    assert_true(dashed.line_style() == LineStyle.DASHED)
    assert_true(square.marker_style() == MarkerStyle.SQUARE)
    var matching_wide = SeriesStyle()
    matching_wide = matching_wide.with_width(2.5)
    assert_true(wide == matching_wide)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
