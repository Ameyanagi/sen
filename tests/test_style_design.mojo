from sen.style import LineCap, LineJoin, SeriesStyle
from std.testing import TestSuite, assert_false, assert_raises, assert_true


def test_line_cap_and_join_nominals_are_distinct_and_validated() raises:
    assert_true(LineCap.BUTT == LineCap.BUTT)
    assert_true(LineCap.ROUND == LineCap.ROUND)
    assert_false(LineCap.BUTT == LineCap.SQUARE)
    assert_true(LineJoin.MITER == LineJoin.MITER)
    assert_true(LineJoin.BEVEL == LineJoin.BEVEL)
    assert_false(LineJoin.MITER == LineJoin.ROUND)

    LineCap.BUTT.validate()
    LineCap.SQUARE.validate()
    LineJoin.MITER.validate()
    LineJoin.BEVEL.validate()
    with assert_raises(contains="line cap is outside Sen's vocabulary"):
        LineCap(_value=-1).validate()
    with assert_raises(contains="line cap is outside Sen's vocabulary"):
        LineCap(_value=3).validate()
    with assert_raises(contains="line join is outside Sen's vocabulary"):
        LineJoin(_value=-1).validate()
    with assert_raises(contains="line join is outside Sen's vocabulary"):
        LineJoin(_value=3).validate()


def test_series_design_defaults_use_points_and_round_strokes() raises:
    var style = SeriesStyle()

    assert_true(style.line_width() == 1.5)
    assert_true(style.marker_size() == 6.0)
    assert_true(style.opacity() == 1.0)
    assert_true(style.line_cap() == LineCap.ROUND)
    assert_true(style.line_join() == LineJoin.ROUND)
    style.validate()


def test_series_design_builders_chain_without_mutating_receiver() raises:
    var original = SeriesStyle(color_index=2)
    var designed = (
        original.with_marker_size(8.5)
        .with_opacity(0.625)
        .with_line_cap(LineCap.SQUARE)
        .with_line_join(LineJoin.BEVEL)
    )

    assert_true(original.marker_size() == 6.0)
    assert_true(original.opacity() == 1.0)
    assert_true(original.line_cap() == LineCap.ROUND)
    assert_true(original.line_join() == LineJoin.ROUND)
    assert_true(designed.marker_size() == 8.5)
    assert_true(designed.opacity() == 0.625)
    assert_true(designed.line_cap() == LineCap.SQUARE)
    assert_true(designed.line_join() == LineJoin.BEVEL)
    assert_false(designed == original)
    assert_true(
        designed
        == SeriesStyle(color_index=2)
        .with_marker_size(8.5)
        .with_opacity(0.625)
        .with_line_cap(LineCap.SQUARE)
        .with_line_join(LineJoin.BEVEL)
    )
    designed.validate()

    assert_false(SeriesStyle() == SeriesStyle().with_marker_size(7.0))
    assert_false(SeriesStyle() == SeriesStyle().with_opacity(0.5))
    assert_false(SeriesStyle() == SeriesStyle().with_line_cap(LineCap.BUTT))
    assert_false(SeriesStyle() == SeriesStyle().with_line_join(LineJoin.MITER))


def test_series_design_builders_reject_invalid_scalars() raises:
    var style = SeriesStyle()
    with assert_raises(contains="marker size must be finite and positive"):
        _ = style.with_marker_size(0.0)
    with assert_raises(contains="marker size must be finite and positive"):
        _ = style.with_marker_size(Float64("inf"))
    with assert_raises(contains="opacity must be finite and in the range 0..1"):
        _ = style.with_opacity(-0.01)
    with assert_raises(contains="opacity must be finite and in the range 0..1"):
        _ = style.with_opacity(1.01)
    with assert_raises(contains="opacity must be finite and in the range 0..1"):
        _ = style.with_opacity(Float64("nan"))

    assert_true(style.with_opacity(0.0).opacity() == 0.0)
    assert_true(style.with_opacity(1.0).opacity() == 1.0)


def test_series_design_validation_covers_direct_storage_corruption() raises:
    var marker_size = SeriesStyle()
    marker_size._marker_size = -1.0
    with assert_raises(contains="marker size must be finite and positive"):
        marker_size.validate()

    var opacity = SeriesStyle()
    opacity._opacity = 1.5
    with assert_raises(contains="opacity must be finite and in the range 0..1"):
        opacity.validate()

    var cap = SeriesStyle().with_line_cap(LineCap(_value=3))
    with assert_raises(contains="line cap is outside Sen's vocabulary"):
        cap.validate()

    var join = SeriesStyle().with_line_join(LineJoin(_value=-1))
    with assert_raises(contains="line join is outside Sen's vocabulary"):
        join.validate()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
