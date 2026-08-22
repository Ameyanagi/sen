from sen import Margins, Rect, plot_area
from std.testing import TestSuite, assert_raises, assert_true


def test_plot_area_uses_y_down_margin_arithmetic() raises:
    var margins = Margins(50.0, 30.0, 20.0, 40.0)
    var area = plot_area(640.0, 480.0, margins)

    assert_true(area.x() == 50.0)
    assert_true(area.y() == 20.0)
    assert_true(area.width() == 560.0)
    assert_true(area.height() == 420.0)
    assert_true(area == Rect(50.0, 20.0, 560.0, 420.0))
    assert_true(margins == Margins(50.0, 30.0, 20.0, 40.0))


def test_margins_reject_negative_and_nonfinite_values() raises:
    with assert_raises(contains="layout margins must be non-negative"):
        _ = Margins(-1.0, 0.0, 0.0, 0.0)
    with assert_raises(contains="layout margins must be non-negative"):
        _ = Margins(0.0, 0.0, -1.0, 0.0)
    with assert_raises(contains="layout margins must be finite"):
        _ = Margins(0.0, Float64("nan"), 0.0, 0.0)
    with assert_raises(contains="layout margins must be finite"):
        _ = Margins(0.0, 0.0, 0.0, Float64("inf"))


def test_rectangle_rejects_invalid_geometry() raises:
    var empty = Rect(1.0, 2.0, 0.0, 0.0)
    assert_true(empty.width() == 0.0)
    assert_true(empty.height() == 0.0)

    with assert_raises(contains="layout rectangle values must be finite"):
        _ = Rect(Float64("nan"), 0.0, 1.0, 1.0)
    with assert_raises(contains="width and height must be non-negative"):
        _ = Rect(0.0, 0.0, -1.0, 1.0)
    with assert_raises(contains="width and height must be non-negative"):
        _ = Rect(0.0, 0.0, 1.0, -1.0)


def test_plot_area_rejects_consumed_or_invalid_figure_size() raises:
    with assert_raises(contains="plot area must have positive width and height"):
        _ = plot_area(100.0, 80.0, Margins(50.0, 50.0, 0.0, 0.0))
    with assert_raises(contains="plot area must have positive width and height"):
        _ = plot_area(100.0, 80.0, Margins(0.0, 0.0, 40.0, 40.0))
    with assert_raises(contains="plot area must have positive width and height"):
        _ = plot_area(100.0, 80.0, Margins(60.0, 50.0, 0.0, 0.0))
    with assert_raises(contains="got width = inf, height = 80.0"):
        _ = plot_area(Float64("inf"), 80.0, Margins(0.0, 0.0, 0.0, 0.0))
    with assert_raises(
        contains=(
            "got plot width = -100.0, plot height = 80.0 "
            "(figure -100.0x80.0 minus margins)"
        )
    ):
        _ = plot_area(-100.0, 80.0, Margins(0.0, 0.0, 0.0, 0.0))


def test_layout_explicit_validation_reports_corrupted_storage() raises:
    var margins = Margins(1.0, 2.0, 3.0, 4.0)
    margins._right = -1.0
    with assert_raises(contains="layout margins must be non-negative"):
        margins.validate()

    var rectangle = Rect(1.0, 2.0, 3.0, 4.0)
    rectangle._height = Float64("nan")
    with assert_raises(contains="layout rectangle values must be finite"):
        rectangle.validate()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
