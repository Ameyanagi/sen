from sen import (
    AxisKind,
    DataBounds,
    Figure,
    LegendPosition,
    LineSeries,
    MissingPolicy,
    PlotPoint,
    ScatterSeries,
)
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


def test_line_series_from_xy_preserves_order_and_computes_bounds() raises:
    var xs: List[Float64] = [4.0, -1.0, 2.0]
    var ys: List[Float64] = [-2.0, 3.0, 1.0]
    var line = LineSeries.from_xy(xs, ys)

    assert_equal(line.point_count(), 3)
    assert_equal(line.segment_count(), 1)
    assert_true(line.point(0).x() == 4.0)
    assert_true(line.point(1).y() == 3.0)
    var bounds = line.bounds()
    assert_true(bounds.x_min() == -1.0)
    assert_true(bounds.x_max() == 4.0)
    assert_true(bounds.y_min() == -2.0)
    assert_true(bounds.y_max() == 3.0)


def test_line_series_from_xy_rejects_invalid_inputs() raises:
    var two_values: List[Float64] = [0.0, 1.0]
    var one_value: List[Float64] = [0.0]
    with assert_raises(contains="coordinate sequences must have equal length"):
        _ = LineSeries.from_xy(two_values, one_value)

    var finite: List[Float64] = [0.0, 1.0]
    var nan_values: List[Float64] = [0.0, Float64("nan")]
    with assert_raises(contains="plot coordinates must be finite"):
        _ = LineSeries.from_xy(nan_values, finite)

    var infinite_values: List[Float64] = [0.0, Float64("inf")]
    with assert_raises(contains="plot coordinates must be finite"):
        _ = LineSeries.from_xy(finite, infinite_values)


def test_append_all_is_all_or_nothing_on_invalid_input() raises:
    var line = LineSeries()
    line.append(PlotPoint(0.0, 1.0))
    var xs: List[Float64] = [2.0, Float64("nan")]
    var ys: List[Float64] = [3.0, 4.0]

    with assert_raises(contains="plot coordinates must be finite"):
        line.append_all(xs, ys)

    assert_equal(line.point_count(), 1)
    assert_equal(line.segment_count(), 1)
    assert_true(line.point(0).x() == 0.0)
    assert_true(line.point(0).y() == 1.0)


def test_append_all_extends_the_last_existing_segment() raises:
    var line = LineSeries()
    line.append(PlotPoint(0.0, 1.0))
    line.start_segment(PlotPoint(2.0, 3.0))
    var xs: List[Float64] = [4.0, 5.0]
    var ys: List[Float64] = [6.0, 7.0]

    line.append_all(xs, ys)

    assert_equal(line.point_count(), 4)
    assert_equal(line.segment_count(), 2)
    assert_equal(line.segment_point_count(0), 1)
    assert_equal(line.segment_point_count(1), 3)
    assert_true(line.segment_point(1, 1).x() == 4.0)
    assert_true(line.segment_point(1, 2).y() == 7.0)


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
    line._ys[0] = Float64("inf")
    with assert_raises(contains="plot coordinates must be finite"):
        line.validate()

    var mismatched = LineSeries()
    mismatched._xs.append(0.0)
    with assert_raises(contains="coordinate buffers must have equal length"):
        mismatched.validate()

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


def test_figure_validate_rejects_corrupted_series() raises:
    var line = LineSeries()
    line.append(PlotPoint(0.0, 1.0))
    line._xs[0] = Float64("nan")
    var figure = Figure()
    figure.add_line(line^)
    with assert_raises(contains="plot coordinates must be finite"):
        figure.validate()


def test_figure_add_line_moves_series() raises:
    var series = LineSeries()
    series.append(PlotPoint(0.0, 1.0))
    series.append(PlotPoint(2.0, 3.0))
    var figure = Figure()

    figure.add_line(series^)

    assert_equal(figure.line_count(), 1)
    ref stored = figure.line(0)
    assert_equal(stored.point_count(), 2)
    assert_true(stored.point(0).x() == 0.0)
    assert_true(stored.point(1).y() == 3.0)


def test_figure_bounds_combine_nonempty_lines_and_skip_empty_lines() raises:
    var first = LineSeries()
    first.append(PlotPoint(-2.0, 4.0))
    first.append(PlotPoint(1.0, -1.0))
    var second = LineSeries()
    second.append(PlotPoint(3.0, 2.0))
    second.append(PlotPoint(0.0, 7.0))
    var figure = Figure()
    figure.add_line(LineSeries())
    figure.add_line(first^)
    figure.add_line(second^)

    var bounds = figure.bounds()
    assert_true(bounds.x_min() == -2.0)
    assert_true(bounds.x_max() == 3.0)
    assert_true(bounds.y_min() == -1.0)
    assert_true(bounds.y_max() == 7.0)


def test_figure_bounds_reject_figures_without_points() raises:
    var empty = Figure()
    with assert_raises(contains="empty figure has no data bounds"):
        _ = empty.bounds()

    var only_empty_lines = Figure()
    only_empty_lines.add_line(LineSeries())
    with assert_raises(contains="empty figure has no data bounds"):
        _ = only_empty_lines.bounds()


def test_figure_owns_renderer_neutral_series() raises:
    var line = LineSeries()
    line.append(PlotPoint(0.0, 1.0))
    var figure = Figure()
    assert_true(figure.is_empty())
    figure.add_line(line.copy())
    line.append(PlotPoint(2.0, 3.0))
    assert_false(figure.is_empty())
    assert_equal(figure.line_count(), 1)
    assert_equal(figure.line(0).point_count(), 1)


def test_figure_line_returns_read_reference() raises:
    var line = LineSeries()
    line.append(PlotPoint(-1.0, 4.0))
    var figure = Figure()
    figure.add_line(line^)

    # A ref binding preserves the accessor's borrowed result instead of copying it.
    ref stored = figure.line(0)
    assert_equal(stored.point_count(), 1)
    assert_true(stored.point(0).x() == -1.0)
    assert_true(stored.point(0).y() == 4.0)


def test_figure_validate_reports_post_insertion_storage_corruption() raises:
    var line = LineSeries()
    line.append(PlotPoint(0.0, 1.0))
    var figure = Figure()
    figure.add_line(line^)
    figure._lines[0]._xs[0] = Float64("nan")
    with assert_raises(contains="plot coordinates must be finite"):
        figure.validate()


def test_mutating_explicit_line_copy_does_not_change_figure() raises:
    var line = LineSeries()
    line.append(PlotPoint(0.0, 1.0))
    var figure = Figure()
    figure.add_line(line^)
    var returned = figure.line(0).copy()
    returned.append(PlotPoint(2.0, 3.0))
    assert_equal(returned.point_count(), 2)
    assert_equal(figure.line(0).point_count(), 1)


def test_missing_policy_error_reports_the_first_missing_observation() raises:
    var xs: List[Float64] = [0.0, Float64("nan"), 2.0]
    var ys: List[Float64] = [1.0, 0.5, 3.0]
    var figure = Figure()

    with assert_raises(
        contains=(
            "missing value at index 1 (x=nan, y=0.5); pass "
            "missing=MissingPolicy.SEGMENT or MissingPolicy.DROP to handle gaps"
        )
    ):
        figure.line(xs, ys)

    assert_equal(figure.line_count(), 0)


def test_missing_policy_segment_builds_exact_gap_topology() raises:
    var nan = Float64("nan")
    var xs: List[Float64] = [nan, 0.0, 1.0, nan, nan, 4.0, 5.0, nan]
    var ys: List[Float64] = [0.0, 1.0, 2.0, nan, 3.0, 5.0, 6.0, nan]
    var figure = Figure()

    figure.line(xs, ys, missing=MissingPolicy.SEGMENT)

    ref line = figure.line(0)
    assert_equal(line.point_count(), 4)
    assert_equal(line.segment_count(), 2)
    assert_equal(line.segment_point_count(0), 2)
    assert_equal(line.segment_point_count(1), 2)
    assert_true(line.segment_point(0, 0).x() == 0.0)
    assert_true(line.segment_point(1, 0).x() == 4.0)


def test_missing_policy_segment_all_missing_produces_an_empty_series() raises:
    var nan = Float64("nan")
    var xs: List[Float64] = [nan, nan, nan]
    var ys: List[Float64] = [0.0, nan, 2.0]
    var figure = Figure()

    figure.line(xs, ys, missing=MissingPolicy.SEGMENT)

    assert_equal(figure.line_count(), 1)
    assert_true(figure.line(0).is_empty())
    assert_equal(figure.line(0).segment_count(), 0)


def test_missing_policy_drop_joins_the_remaining_line_points() raises:
    var xs: List[Float64] = [0.0, Float64("nan"), 2.0, 3.0]
    var ys: List[Float64] = [1.0, 5.0, Float64("nan"), 4.0]
    var figure = Figure()

    figure.line(xs, ys, missing=MissingPolicy.DROP)

    ref line = figure.line(0)
    assert_equal(line.point_count(), 2)
    assert_equal(line.segment_count(), 1)
    assert_equal(line.segment_point_count(0), 2)
    assert_true(line.point(0).x() == 0.0)
    assert_true(line.point(1).x() == 3.0)


def test_non_nan_infinities_raise_under_every_missing_policy() raises:
    var positive: List[Float64] = [0.0, Float64("inf")]
    var negative: List[Float64] = [0.0, Float64("-inf")]
    var finite: List[Float64] = [1.0, 2.0]
    var error_positive = Figure()
    var segment_positive = Figure()
    var drop_positive = Figure()
    var error_negative = Figure()
    var segment_negative = Figure()
    var drop_negative = Figure()
    var scatter_error = Figure()
    var scatter_segment = Figure()
    var scatter_drop = Figure()

    with assert_raises(contains="plot coordinates must be finite"):
        error_positive.line(positive, finite, missing=MissingPolicy.ERROR)
    with assert_raises(contains="plot coordinates must be finite"):
        segment_positive.line(positive, finite, missing=MissingPolicy.SEGMENT)
    with assert_raises(contains="plot coordinates must be finite"):
        drop_positive.line(positive, finite, missing=MissingPolicy.DROP)
    with assert_raises(contains="plot coordinates must be finite"):
        error_negative.line(finite, negative, missing=MissingPolicy.ERROR)
    with assert_raises(contains="plot coordinates must be finite"):
        segment_negative.line(finite, negative, missing=MissingPolicy.SEGMENT)
    with assert_raises(contains="plot coordinates must be finite"):
        drop_negative.line(finite, negative, missing=MissingPolicy.DROP)
    with assert_raises(contains="plot coordinates must be finite"):
        scatter_error.scatter(positive, finite, missing=MissingPolicy.ERROR)
    with assert_raises(contains="plot coordinates must be finite"):
        scatter_segment.scatter(positive, finite, missing=MissingPolicy.SEGMENT)
    with assert_raises(contains="plot coordinates must be finite"):
        scatter_drop.scatter(positive, finite, missing=MissingPolicy.DROP)

    var nan_and_inf_x: List[Float64] = [Float64("nan")]
    var nan_and_inf_y: List[Float64] = [Float64("inf")]
    var mixed_segment = Figure()
    var mixed_drop = Figure()
    with assert_raises(contains="plot coordinates must be finite"):
        mixed_segment.line(
            nan_and_inf_x,
            nan_and_inf_y,
            missing=MissingPolicy.SEGMENT,
        )
    with assert_raises(contains="plot coordinates must be finite"):
        mixed_drop.scatter(
            nan_and_inf_x,
            nan_and_inf_y,
            missing=MissingPolicy.DROP,
        )


def test_scatter_series_bulk_append_bounds_and_validation() raises:
    var xs: List[Float64] = [4.0, -1.0, 2.0]
    var ys: List[Float64] = [-2.0, 3.0, 1.0]
    var scatter = ScatterSeries.from_xy(xs, ys)

    scatter.append(PlotPoint(6.0, -5.0))

    assert_equal(scatter.point_count(), 4)
    assert_true(scatter.point(0).x() == 4.0)
    assert_true(scatter.point(3).y() == -5.0)
    var bounds = scatter.bounds()
    assert_true(bounds.x_min() == -1.0)
    assert_true(bounds.x_max() == 6.0)
    assert_true(bounds.y_min() == -5.0)
    assert_true(bounds.y_max() == 3.0)
    scatter.validate()


def test_scatter_series_rejects_invalid_inputs_and_empty_bounds() raises:
    var empty = ScatterSeries()
    assert_true(empty.is_empty())
    with assert_raises(contains="empty scatter-series has no data bounds"):
        _ = empty.bounds()
    with assert_raises(contains="scatter-series point index is out of bounds"):
        _ = empty.point(0)

    var two_values: List[Float64] = [0.0, 1.0]
    var one_value: List[Float64] = [0.0]
    with assert_raises(contains="coordinate sequences must have equal length"):
        _ = ScatterSeries.from_xy(two_values, one_value)

    var nonfinite: List[Float64] = [0.0, Float64("inf")]
    with assert_raises(contains="plot coordinates must be finite"):
        _ = ScatterSeries.from_xy(two_values, nonfinite)

    var invalid = PlotPoint(0.0, 1.0)
    invalid._x = Float64("nan")
    with assert_raises(contains="plot coordinates must be finite"):
        empty.append(invalid)

    var mismatched = ScatterSeries()
    mismatched._xs.append(0.0)
    with assert_raises(contains="coordinate buffers must have equal length"):
        mismatched.validate()


def test_scatter_segment_and_drop_missing_policies_are_identical() raises:
    var xs: List[Float64] = [0.0, Float64("nan"), 2.0, 3.0]
    var ys: List[Float64] = [1.0, 4.0, Float64("nan"), 5.0]
    var segmented = Figure()
    var dropped = Figure()
    var error = Figure()

    with assert_raises(contains="missing value at index 1"):
        error.scatter(xs, ys)
    segmented.scatter(xs, ys, missing=MissingPolicy.SEGMENT)
    dropped.scatter(xs, ys, missing=MissingPolicy.DROP)

    ref segmented_series = segmented.scatter(0)
    ref dropped_series = dropped.scatter(0)
    assert_equal(segmented_series.point_count(), dropped_series.point_count())
    for index in range(segmented_series.point_count()):
        assert_true(
            segmented_series.point(index).x() == dropped_series.point(index).x()
        )
        assert_true(
            segmented_series.point(index).y() == dropped_series.point(index).y()
        )


def test_figure_one_call_entries_store_labels_and_check_lengths() raises:
    var xs: List[Float64] = [0.0, 1.0]
    var ys: List[Float64] = [1.0, 2.0]
    var one_value: List[Float64] = [0.0]
    var figure = Figure()

    figure.line(xs, ys, label="trend")
    figure.scatter(xs, ys, label="samples")
    figure.line(xs, ys, label="forecast")

    assert_equal(figure.line_count(), 2)
    assert_equal(figure.scatter_count(), 1)
    assert_equal(figure.line_label(0), "trend")
    assert_equal(figure.line_label(1), "forecast")
    assert_equal(figure.scatter_label(0), "samples")
    with assert_raises(contains="coordinate sequences must have equal length"):
        figure.line(xs, one_value)
    with assert_raises(contains="coordinate sequences must have equal length"):
        figure.scatter(xs, one_value)


def test_figure_lower_level_add_paths_use_empty_labels() raises:
    var line = LineSeries()
    line.append(PlotPoint(0.0, 1.0))
    var scatter = ScatterSeries()
    scatter.append(PlotPoint(2.0, 3.0))
    var figure = Figure()

    figure.add_line(line^)
    figure.add_scatter(scatter^)

    assert_equal(figure.line_label(0), "")
    assert_equal(figure.scatter_label(0), "")
    assert_true(not figure.is_empty())


def test_figure_bounds_and_validation_cover_lines_and_scatters() raises:
    var line = LineSeries()
    line.append(PlotPoint(-2.0, 4.0))
    var scatter = ScatterSeries()
    scatter.append(PlotPoint(5.0, -3.0))
    var figure = Figure()
    figure.add_scatter(ScatterSeries())
    figure.add_line(line^)
    figure.add_scatter(scatter^)

    var bounds = figure.bounds()
    assert_true(bounds.x_min() == -2.0)
    assert_true(bounds.x_max() == 5.0)
    assert_true(bounds.y_min() == -3.0)
    assert_true(bounds.y_max() == 4.0)
    figure.validate()

    var only_empty_scatter = Figure()
    assert_true(only_empty_scatter.is_empty())
    only_empty_scatter.add_scatter(ScatterSeries())
    assert_false(only_empty_scatter.is_empty())
    with assert_raises(contains="empty figure has no data bounds"):
        _ = only_empty_scatter.bounds()


def test_figure_scatter_indices_and_corruption_are_checked() raises:
    var figure = Figure()
    with assert_raises(contains="figure scatter index is out of bounds"):
        _ = figure.scatter(0)
    with assert_raises(contains="figure line-label index is out of bounds"):
        _ = figure.line_label(0)
    with assert_raises(contains="figure scatter-label index is out of bounds"):
        _ = figure.scatter_label(0)

    var scatter = ScatterSeries()
    scatter.append(PlotPoint(0.0, 1.0))
    figure.add_scatter(scatter^)
    figure._scatters[0]._ys[0] = Float64("nan")
    with assert_raises(contains="plot coordinates must be finite"):
        figure.validate()


def test_figure_text_setters_round_trip_any_string() raises:
    var figure = Figure()

    assert_equal(figure.title(), "")
    assert_equal(figure.x_label(), "")
    assert_equal(figure.y_label(), "")

    figure.set_title("A <title>")
    figure.set_x_label("x & time")
    figure.set_y_label("'value'")

    assert_equal(figure.title(), "A <title>")
    assert_equal(figure.x_label(), "x & time")
    assert_equal(figure.y_label(), "'value'")


def test_figure_legend_and_grid_defaults_and_setters() raises:
    var figure = Figure()

    assert_true(figure.legend_position() == LegendPosition.UPPER_RIGHT)
    assert_false(figure.grid_enabled())

    figure.set_legend(LegendPosition.LOWER_LEFT)
    figure.set_grid(True)

    assert_true(figure.legend_position() == LegendPosition.LOWER_LEFT)
    assert_true(figure.grid_enabled())


def test_figure_axis_scale_defaults_and_setters_round_trip() raises:
    var figure = Figure()

    assert_true(figure.x_scale() == AxisKind.LINEAR)
    assert_true(figure.y_scale() == AxisKind.LINEAR)

    figure.set_x_scale(AxisKind.LOG10)
    figure.set_y_scale(AxisKind.LOG10)

    assert_true(figure.x_scale() == AxisKind.LOG10)
    assert_true(figure.y_scale() == AxisKind.LOG10)


def test_figure_axis_limits_validate_and_round_trip() raises:
    var figure = Figure()
    assert_true(not figure.x_limits())
    assert_true(not figure.y_limits())

    figure.set_x_limits(-2.5, 3.5)
    figure.set_y_limits(10.0, 20.0)

    var x_limits = figure.x_limits().value()
    var y_limits = figure.y_limits().value()
    assert_true(x_limits[0] == -2.5)
    assert_true(x_limits[1] == 3.5)
    assert_true(y_limits[0] == 10.0)
    assert_true(y_limits[1] == 20.0)


def test_figure_axis_limits_reject_invalid_values_with_context() raises:
    var figure = Figure()
    with assert_raises(contains="lo = 3.0, hi = 3.0"):
        figure.set_x_limits(3.0, 3.0)
    with assert_raises(contains="lo = 4.0, hi = -1.0"):
        figure.set_x_limits(4.0, -1.0)
    with assert_raises(contains="lo = nan, hi = 1.0"):
        figure.set_x_limits(Float64("nan"), 1.0)
    with assert_raises(contains="lo = 0.0, hi = inf"):
        figure.set_x_limits(0.0, Float64("inf"))

    with assert_raises(contains="lo = 2.0, hi = 2.0"):
        figure.set_y_limits(2.0, 2.0)
    with assert_raises(contains="lo = 5.0, hi = 4.0"):
        figure.set_y_limits(5.0, 4.0)
    with assert_raises(contains="lo = -inf, hi = 1.0"):
        figure.set_y_limits(Float64("-inf"), 1.0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
