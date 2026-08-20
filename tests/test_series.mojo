from sen import DataBounds, Figure, LineSeries, PlotPoint
from std.collections import List
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)


def test_empty_series_has_no_bounds() raises:
    var line = LineSeries()
    assert_true(line.is_empty())
    with assert_raises(contains="empty line-series has no data bounds"):
        _ = line.bounds()


def test_line_series_preserves_order_and_computes_bounds() raises:
    var line = LineSeries()
    line.append(PlotPoint(4.0, -2.0))
    line.append(PlotPoint(-1.0, 3.0))
    line.append(PlotPoint(2.0, 1.0))
    assert_equal(line.point_count(), 3)
    assert_true(line.point(0).x() == 4.0)
    assert_true(line.point(1).x() == -1.0)
    assert_true(line.point(2).x() == 2.0)
    var bounds = line.bounds()
    assert_true(bounds.x_min() == -1.0)
    assert_true(bounds.x_max() == 4.0)
    assert_true(bounds.y_min() == -2.0)
    assert_true(bounds.y_max() == 3.0)


def test_single_point_bounds_equal_the_point() raises:
    var line = LineSeries()
    line.append(PlotPoint(2.5, -4.0))

    var bounds = line.bounds()
    assert_true(bounds.x_min() == 2.5)
    assert_true(bounds.x_max() == 2.5)
    assert_true(bounds.y_min() == -4.0)
    assert_true(bounds.y_max() == -4.0)


def test_explicit_segments_represent_gaps_without_nonfinite_points() raises:
    var line = LineSeries()
    assert_equal(line.segment_count(), 0)
    line.append(PlotPoint(0.0, 1.0))
    line.append(PlotPoint(1.0, 2.0))
    line.start_segment(PlotPoint(3.0, -1.0))
    line.append(PlotPoint(4.0, 5.0))

    assert_equal(line.point_count(), 4)
    assert_equal(line.segment_count(), 2)
    assert_equal(line.segment_point_count(0), 2)
    assert_equal(line.segment_point_count(1), 2)
    assert_true(line.segment_point(0, 1).x() == 1.0)
    assert_true(line.segment_point(1, 0).x() == 3.0)

    var bounds = line.bounds()
    assert_true(bounds.x_min() == 0.0)
    assert_true(bounds.x_max() == 4.0)
    assert_true(bounds.y_min() == -1.0)
    assert_true(bounds.y_max() == 5.0)


def test_line_series_accepts_prebuilt_points_and_segments() raises:
    var points = List[PlotPoint]()
    points.append(PlotPoint(0.0, 1.0))
    points.append(PlotPoint(1.0, 2.0))
    points.append(PlotPoint(3.0, -1.0))
    points.append(PlotPoint(4.0, 5.0))
    var segment_starts = List[Int]()
    segment_starts.append(0)
    segment_starts.append(2)

    var line = LineSeries(points^, segment_starts^)
    assert_equal(line.point_count(), 4)
    assert_equal(line.segment_count(), 2)
    assert_equal(line.segment_point_count(0), 2)
    assert_equal(line.segment_point_count(1), 2)
    assert_true(line.segment_point(1, 0).x() == 3.0)


def test_segment_boundaries_are_nominal_and_checked() raises:
    var line = LineSeries()
    with assert_raises(contains="new line segment requires an existing point"):
        line.start_segment(PlotPoint(1.0, 2.0))

    line.append(PlotPoint(0.0, 1.0))
    with assert_raises(contains="line-series segment index is out of bounds"):
        _ = line.segment_point_count(-1)
    with assert_raises(contains="line-series segment index is out of bounds"):
        _ = line.segment_point_count(1)
    with assert_raises(contains="line-segment point index is out of bounds"):
        _ = line.segment_point(0, 1)


def test_series_and_figure_indices_are_checked() raises:
    var line = LineSeries()
    with assert_raises(contains="line-series point index is out of bounds"):
        _ = line.point(0)
    line.append(PlotPoint(0.0, 1.0))
    with assert_raises(contains="line-series point index is out of bounds"):
        _ = line.point(-1)
    var figure = Figure()
    with assert_raises(contains="figure line index is out of bounds"):
        _ = figure.line(0)


def test_plot_points_reject_non_finite_coordinates() raises:
    with assert_raises(contains="plot coordinates must be finite"):
        _ = PlotPoint(Float64("nan"), 0.0)
    with assert_raises(contains="plot coordinates must be finite"):
        _ = PlotPoint(Float64("inf"), 0.0)


def test_data_bounds_validate_finite_ordered_extents() raises:
    var bounds = DataBounds(-1.0, 2.0, -3.0, 4.0)
    assert_true(bounds.x_min() == -1.0)
    assert_true(bounds.y_max() == 4.0)
    with assert_raises(contains="data bounds must be finite"):
        _ = DataBounds(Float64("nan"), 1.0, 0.0, 1.0)
    with assert_raises(contains="x minimum must not exceed"):
        _ = DataBounds(2.0, 1.0, 0.0, 1.0)
    with assert_raises(contains="y minimum must not exceed"):
        _ = DataBounds(0.0, 1.0, 2.0, 1.0)


def test_data_bounds_including_expands_in_each_direction() raises:
    var bounds = DataBounds(0.0, 1.0, 0.0, 1.0)

    bounds = bounds.including(PlotPoint(-1.0, 0.5))
    assert_true(bounds.x_min() == -1.0)
    bounds = bounds.including(PlotPoint(2.0, 0.5))
    assert_true(bounds.x_max() == 2.0)
    bounds = bounds.including(PlotPoint(0.5, -2.0))
    assert_true(bounds.y_min() == -2.0)
    bounds = bounds.including(PlotPoint(0.5, 3.0))
    assert_true(bounds.y_max() == 3.0)


def test_explicit_validation_reports_mutated_storage() raises:
    var point = PlotPoint(1.0, 2.0)
    point._x = Float64("nan")
    with assert_raises(contains="plot coordinates must be finite"):
        point.validate()

    var points = List[PlotPoint]()
    points.append(PlotPoint(0.0, 1.0))
    var line = LineSeries(points^)
    line._points[0]._y = Float64("inf")
    with assert_raises(contains="plot coordinates must be finite"):
        line.validate()

    var segmented = LineSeries()
    segmented.append(PlotPoint(0.0, 1.0))
    segmented.start_segment(PlotPoint(2.0, 3.0))
    segmented._segment_starts[1] = 0
    with assert_raises(contains="segment starts must be strictly increasing"):
        segmented.validate()

    var bounds = DataBounds(0.0, 1.0, 0.0, 1.0)
    bounds._x_min = 2.0
    with assert_raises(contains="x minimum must not exceed"):
        bounds.validate()


def test_line_series_constructor_and_mutators_validate_points() raises:
    var invalid = PlotPoint(0.0, 1.0)
    invalid._y = Float64("nan")

    var points = List[PlotPoint]()
    points.append(invalid)
    with assert_raises(contains="plot coordinates must be finite"):
        _ = LineSeries(points^)

    var line = LineSeries()
    with assert_raises(contains="plot coordinates must be finite"):
        line.append(invalid)
    line.append(PlotPoint(0.0, 1.0))
    with assert_raises(contains="plot coordinates must be finite"):
        line.start_segment(invalid)


def test_line_series_validate_checks_every_topology_boundary() raises:
    var empty = LineSeries()
    empty._segment_starts.append(0)
    with assert_raises(contains="empty line-series must not contain segments"):
        empty.validate()

    var missing_first = LineSeries()
    missing_first.append(PlotPoint(0.0, 0.0))
    missing_first._segment_starts = List[Int]()
    with assert_raises(contains="nonempty line-series must start with segment zero"):
        missing_first.validate()

    var wrong_first = LineSeries()
    wrong_first.append(PlotPoint(0.0, 0.0))
    wrong_first.append(PlotPoint(1.0, 1.0))
    wrong_first._segment_starts[0] = 1
    with assert_raises(contains="nonempty line-series must start with segment zero"):
        wrong_first.validate()

    var duplicate = LineSeries()
    duplicate.append(PlotPoint(0.0, 0.0))
    duplicate.start_segment(PlotPoint(1.0, 1.0))
    duplicate._segment_starts[1] = 0
    with assert_raises(contains="segment starts must be strictly increasing"):
        duplicate.validate()

    var out_of_order = LineSeries()
    out_of_order.append(PlotPoint(0.0, 0.0))
    out_of_order.append(PlotPoint(1.0, 1.0))
    out_of_order.start_segment(PlotPoint(2.0, 2.0))
    out_of_order.start_segment(PlotPoint(3.0, 3.0))
    out_of_order._segment_starts[2] = 1
    with assert_raises(contains="segment starts must be strictly increasing"):
        out_of_order.validate()

    var out_of_range = LineSeries()
    out_of_range.append(PlotPoint(0.0, 0.0))
    out_of_range.start_segment(PlotPoint(1.0, 1.0))
    out_of_range._segment_starts[1] = out_of_range.point_count()
    with assert_raises(contains="segment start is outside point storage"):
        out_of_range.validate()


def test_figure_rejects_corrupted_series() raises:
    var line = LineSeries()
    line.append(PlotPoint(0.0, 1.0))
    line._points[0]._x = Float64("nan")
    var figure = Figure()
    with assert_raises(contains="plot coordinates must be finite"):
        figure.add_line(line)


def test_figure_owns_renderer_neutral_series() raises:
    var line = LineSeries()
    line.append(PlotPoint(0.0, 1.0))
    var figure = Figure()
    assert_true(figure.is_empty())
    figure.add_line(line)
    line.append(PlotPoint(2.0, 3.0))
    assert_false(figure.is_empty())
    assert_equal(figure.line_count(), 1)
    assert_equal(figure.line(0).point_count(), 1)


def test_figure_validate_reports_post_insertion_storage_corruption() raises:
    var line = LineSeries()
    line.append(PlotPoint(0.0, 1.0))
    var figure = Figure()
    figure.add_line(line)
    figure._lines[0]._points[0]._x = Float64("nan")
    with assert_raises(contains="plot coordinates must be finite"):
        figure.validate()


def test_mutating_returned_line_copy_does_not_change_figure() raises:
    var line = LineSeries()
    line.append(PlotPoint(0.0, 1.0))
    var figure = Figure()
    figure.add_line(line)
    var returned = figure.line(0)
    returned.append(PlotPoint(2.0, 3.0))
    assert_equal(returned.point_count(), 2)
    assert_equal(figure.line(0).point_count(), 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
