from sen import LineStyle, MarkerStyle, SeriesStyle
from sen.style import _parse_hex_color
from std.testing import (
    TestSuite,
    assert_equal,
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
    assert_equal(style.color(), "")
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
        _ = style.with_line_width(0.0)
    with assert_raises(contains="got -1.0"):
        _ = style.with_line_width(-1.0)
    with assert_raises(contains="got inf"):
        _ = style.with_line_width(Float64("inf"))
    with assert_raises(contains="got nan"):
        _ = style.with_line_width(Float64("nan"))


def test_series_style_builders_modify_copies_only() raises:
    var original = SeriesStyle()
    var wide = original.with_line_width(2.5)
    var dashed = original.with_line_style(LineStyle.DASHED)
    var square = original.with_marker_style(MarkerStyle.SQUARE)

    assert_true(original.palette_slot() == -1)
    assert_true(original.line_style() == LineStyle.SOLID)
    assert_true(original.marker_style() == MarkerStyle.CIRCLE)
    assert_true(original.line_width() == 1.5)
    assert_true(wide.line_width() == 2.5)
    assert_true(dashed.line_style() == LineStyle.DASHED)
    assert_true(square.marker_style() == MarkerStyle.SQUARE)
    var matching_wide = SeriesStyle()
    matching_wide = matching_wide.with_line_width(2.5)
    assert_true(wide == matching_wide)


def test_hex_color_parser_is_strict_and_normalizes_case() raises:
    assert_equal(_parse_hex_color("#1f77b4"), "#1f77b4")
    assert_equal(_parse_hex_color("#1F77B4"), "#1f77b4")

    with assert_raises(
        contains=(
            "series color must be '#' followed by exactly six hexadecimal digits, "
            "like '#1f77b4'; got '1f77b4'"
        )
    ):
        _ = _parse_hex_color("1f77b4")
    with assert_raises(
        contains=(
            "series color must be '#' followed by exactly six hexadecimal digits, "
            "like '#1f77b4'; got '#12345'"
        )
    ):
        _ = _parse_hex_color("#12345")
    with assert_raises(
        contains=(
            "series color must be '#' followed by exactly six hexadecimal digits, "
            "like '#1f77b4'; got '#12345g'"
        )
    ):
        _ = _parse_hex_color("#12345g")


def test_custom_color_construction_and_builder_precede_palette_slots() raises:
    var direct = SeriesStyle(color="#1F77B4")
    assert_equal(direct.color(), "#1f77b4")
    assert_true(direct.palette_slot() == -1)

    var explicit = SeriesStyle(color_index=4).with_color("#8B1E3F")
    assert_equal(explicit.color(), "#8b1e3f")
    assert_true(explicit.palette_slot() == 4)
    assert_true(explicit == SeriesStyle(color_index=4).with_color("#8b1e3f"))
    assert_false(explicit == SeriesStyle(color_index=4))
    explicit.validate()

    var corrupted = SeriesStyle()
    corrupted._custom_color = String("#12345g")
    with assert_raises(contains="got '#12345g'"):
        corrupted.validate()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
