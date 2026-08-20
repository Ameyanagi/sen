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
    assert_false(line.bounds())


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
    assert_true(bounds)
    assert_true(bounds.value().x_min() == -1.0)
    assert_true(bounds.value().x_max() == 4.0)
    assert_true(bounds.value().y_min() == -2.0)
    assert_true(bounds.value().y_max() == 3.0)


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
    assert_true(bounds)
    assert_true(bounds.value().x_min() == 0.0)
    assert_true(bounds.value().x_max() == 4.0)
    assert_true(bounds.value().y_min() == -1.0)
    assert_true(bounds.value().y_max() == 5.0)


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


def test_semantic_operations_revalidate_mutated_storage() raises:
    var point = PlotPoint(1.0, 2.0)
    point._x = Float64("nan")
    with assert_raises(contains="plot coordinates must be finite"):
        _ = point.x()

    var points = List[PlotPoint]()
    points.append(PlotPoint(0.0, 1.0))
    var line = LineSeries(points^)
    line._points[0]._y = Float64("inf")
    with assert_raises(contains="plot coordinates must be finite"):
        _ = line.point(0)
    with assert_raises(contains="plot coordinates must be finite"):
        _ = line.bounds()

    var segmented = LineSeries()
    segmented.append(PlotPoint(0.0, 1.0))
    segmented.start_segment(PlotPoint(2.0, 3.0))
    segmented._segment_starts[1] = 0
    with assert_raises(contains="segment starts must be strictly increasing"):
        _ = segmented.segment_count()
    with assert_raises(contains="segment starts must be strictly increasing"):
        _ = segmented.segment_point_count(0)
    with assert_raises(contains="segment starts must be strictly increasing"):
        _ = segmented.bounds()
    with assert_raises(contains="segment starts must be strictly increasing"):
        segmented.append(PlotPoint(4.0, 5.0))

    var bounds = DataBounds(0.0, 1.0, 0.0, 1.0)
    bounds._x_min = 2.0
    with assert_raises(contains="x minimum must not exceed"):
        _ = bounds.x_min()
    with assert_raises(contains="x minimum must not exceed"):
        _ = bounds.including(PlotPoint(3.0, 3.0))


def test_segment_count_revalidates_every_topology_boundary() raises:
    var empty = LineSeries()
    empty._segment_starts.append(0)
    with assert_raises(contains="empty line-series must not contain segments"):
        _ = empty.segment_count()

    var missing_first = LineSeries()
    missing_first.append(PlotPoint(0.0, 0.0))
    missing_first._segment_starts = List[Int]()
    with assert_raises(contains="nonempty line-series must start with segment zero"):
        _ = missing_first.segment_count()

    var wrong_first = LineSeries()
    wrong_first.append(PlotPoint(0.0, 0.0))
    wrong_first.append(PlotPoint(1.0, 1.0))
    wrong_first._segment_starts[0] = 1
    with assert_raises(contains="nonempty line-series must start with segment zero"):
        _ = wrong_first.segment_count()

    var duplicate = LineSeries()
    duplicate.append(PlotPoint(0.0, 0.0))
    duplicate.start_segment(PlotPoint(1.0, 1.0))
    duplicate._segment_starts[1] = 0
    with assert_raises(contains="segment starts must be strictly increasing"):
        _ = duplicate.segment_count()

    var out_of_order = LineSeries()
    out_of_order.append(PlotPoint(0.0, 0.0))
    out_of_order.append(PlotPoint(1.0, 1.0))
    out_of_order.start_segment(PlotPoint(2.0, 2.0))
    out_of_order.start_segment(PlotPoint(3.0, 3.0))
    out_of_order._segment_starts[2] = 1
    with assert_raises(contains="segment starts must be strictly increasing"):
        _ = out_of_order.segment_count()

    var out_of_range = LineSeries()
    out_of_range.append(PlotPoint(0.0, 0.0))
    out_of_range.start_segment(PlotPoint(1.0, 1.0))
    out_of_range._segment_starts[1] = out_of_range.point_count()
    with assert_raises(contains="segment start is outside point storage"):
        _ = out_of_range.segment_count()


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


def test_figure_revalidates_post_insertion_storage_corruption() raises:
    var line = LineSeries()
    line.append(PlotPoint(0.0, 1.0))
    var figure = Figure()
    figure.add_line(line)
    figure._lines[0]._points[0]._x = Float64("nan")
    with assert_raises(contains="plot coordinates must be finite"):
        _ = figure.line(0)


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
