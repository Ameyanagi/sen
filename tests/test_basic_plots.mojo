from sen import (
    AxisKind,
    DataRectangle,
    Figure,
    Plot,
    RectangleSeries,
    StepMode,
    render_svg,
)
from std.collections import List
from std.testing import TestSuite, assert_equal, assert_raises, assert_true


def first_occurrence(text: StringSlice, needle: StringSlice, start: Int = 0) -> Int:
    var index = start
    while index + needle.byte_length() <= text.byte_length():
        if text[byte = index : index + needle.byte_length()] == needle:
            return index
        index += 1
    return -1


def count_occurrences(text: StringSlice, needle: StringSlice) -> Int:
    var count = 0
    var start = 0
    while True:
        var found = first_occurrence(text, needle, start)
        if found < 0:
            return count
        count += 1
        start = found + needle.byte_length()


def test_step_modes_have_exact_transition_geometry() raises:
    var x: List[Float64] = [0.0, 2.0, 4.0]
    var y: List[Float64] = [1.0, 3.0, 2.0]
    var figure = Figure()
    figure.step(x, y, mode=StepMode.PRE, label="pre")
    figure.step(x, y, mode=StepMode.POST, label="post")
    figure.step(x, y, mode=StepMode.MID, label="mid")

    assert_equal(figure.line_count(), 3)
    assert_equal(figure.line_label(0), "pre")
    assert_equal(figure.line_label(1), "post")
    assert_equal(figure.line_label(2), "mid")

    ref pre = figure.line(0)
    assert_equal(pre.point_count(), 5)
    assert_true(pre.point(0).x() == 0.0 and pre.point(0).y() == 1.0)
    assert_true(pre.point(1).x() == 0.0 and pre.point(1).y() == 3.0)
    assert_true(pre.point(2).x() == 2.0 and pre.point(2).y() == 3.0)

    ref post = figure.line(1)
    assert_equal(post.point_count(), 5)
    assert_true(post.point(0).x() == 0.0 and post.point(0).y() == 1.0)
    assert_true(post.point(1).x() == 2.0 and post.point(1).y() == 1.0)
    assert_true(post.point(2).x() == 2.0 and post.point(2).y() == 3.0)

    ref mid = figure.line(2)
    assert_equal(mid.point_count(), 6)
    assert_true(mid.point(1).x() == 1.0 and mid.point(1).y() == 1.0)
    assert_true(mid.point(2).x() == 1.0 and mid.point(2).y() == 3.0)
    assert_true(mid.point(3).x() == 3.0 and mid.point(3).y() == 3.0)
    assert_true(mid.point(4).x() == 3.0 and mid.point(4).y() == 2.0)


def test_stem_is_one_segmented_series_including_baseline() raises:
    var x: List[Float64] = [1.0, 2.0]
    var y: List[Float64] = [-1.0, 3.0]
    var figure = Figure()
    figure.stem(x, y, baseline=0.5, label="samples")

    assert_equal(figure.line_count(), 1)
    assert_equal(figure.line_label(0), "samples")
    ref stems = figure.line(0)
    assert_equal(stems.segment_count(), 2)
    assert_equal(stems.segment_point_count(0), 2)
    assert_equal(stems.segment_point_count(1), 2)
    assert_true(stems.segment_point(0, 0).y() == 0.5)
    assert_true(stems.segment_point(0, 1).y() == -1.0)
    assert_true(stems.segment_point(1, 0).y() == 0.5)
    assert_true(stems.segment_point(1, 1).y() == 3.0)
    var bounds = stems.bounds()
    assert_true(bounds.y_min() == -1.0 and bounds.y_max() == 3.0)


def test_symmetric_errorbars_lower_to_one_labeled_series() raises:
    var x: List[Float64] = [2.0]
    var y: List[Float64] = [5.0]
    var x_error: List[Float64] = [0.5]
    var y_error: List[Float64] = [1.5]
    var figure = Figure()
    figure.errorbar(
        x,
        y,
        x_error,
        y_error,
        cap_size=0.4,
        label="uncertainty",
    )

    assert_equal(figure.line_count(), 1)
    assert_equal(figure.line_label(0), "uncertainty")
    ref bars = figure.line(0)
    assert_equal(bars.segment_count(), 6)
    assert_equal(bars.point_count(), 12)
    assert_true(bars.segment_point(0, 0).x() == 1.5)
    assert_true(bars.segment_point(0, 1).x() == 2.5)
    assert_true(bars.segment_point(3, 0).y() == 3.5)
    assert_true(bars.segment_point(3, 1).y() == 6.5)
    assert_true(bars.bounds().x_min() == 1.5)
    assert_true(bars.bounds().x_max() == 2.5)


def test_rectangle_series_validates_and_preserves_edges() raises:
    var left: List[Float64] = [-1.0, 2.0]
    var right: List[Float64] = [0.0, 4.0]
    var bottom: List[Float64] = [-2.0, 0.0]
    var top: List[Float64] = [3.0, 5.0]
    var rectangles = RectangleSeries.from_edges(left, right, bottom, top)
    rectangles.append(DataRectangle(5.0, 6.0, 1.0, 2.0))

    assert_equal(rectangles.rectangle_count(), 3)
    assert_true(rectangles.rectangle(0).left() == -1.0)
    assert_true(rectangles.rectangle(1).top() == 5.0)
    assert_true(rectangles.bounds().x_max() == 6.0)
    assert_true(rectangles.bounds().y_min() == -2.0)


def test_numeric_and_categorical_bars_are_filled_rectangle_series() raises:
    var x: List[Float64] = [1.0, 3.0]
    var height: List[Float64] = [-1.0, 4.0]
    var figure = Figure()
    figure.bar(x, height, width=1.0, baseline=0.5, label="numeric")

    assert_equal(figure.rectangle_count(), 1)
    assert_equal(figure.rectangle_label(0), "numeric")
    ref numeric = figure.rectangles(0)
    assert_true(numeric.rectangle(0).left() == 0.5)
    assert_true(numeric.rectangle(0).right() == 1.5)
    assert_true(numeric.rectangle(0).bottom() == -0.5)
    assert_true(numeric.rectangle(0).top() == 0.5)
    assert_true(numeric.rectangle(1).bottom() == 0.5)
    assert_true(numeric.rectangle(1).top() == 4.5)

    var categories: List[String] = ["alpha", "b&b", "雪"]
    var values: List[Float64] = [2.0, 1.0, 3.0]
    figure.bar(categories, values, label="categorical")
    assert_equal(figure.rectangle_count(), 2)
    assert_true(figure.has_explicit_x_ticks())
    assert_equal(figure.x_tick_count(), 3)
    assert_true(figure.x_tick_position(1) == 1.0)
    assert_equal(figure.x_tick_label(0), "alpha")
    assert_equal(figure.x_tick_label(1), "b&b")
    assert_equal(figure.x_tick_label(2), "雪")

    figure.bar(categories, values, label="same domain")
    var reordered: List[String] = ["b&b", "alpha", "雪"]
    with assert_raises(contains="categorical bar domain differs"):
        figure.bar(reordered, values)
    assert_equal(figure.rectangle_count(), 3)


def test_histogram_counts_boundaries_and_explicit_range() raises:
    var data: List[Float64] = [0.0, 0.5, 1.0, 1.0, 2.0, 3.0]
    var figure = Figure()
    figure.histogram(data, bins=3, label="observed")
    figure.histogram(data, 0.0, 2.0, bins=2, label="clipped")

    assert_equal(figure.rectangle_count(), 2)
    ref observed = figure.rectangles(0)
    assert_equal(observed.rectangle_count(), 3)
    assert_true(observed.rectangle(0).left() == 0.0)
    assert_true(observed.rectangle(2).right() == 3.0)
    assert_true(observed.rectangle(0).top() == 2.0)
    assert_true(observed.rectangle(1).top() == 2.0)
    assert_true(observed.rectangle(2).top() == 2.0)

    ref clipped = figure.rectangles(1)
    assert_equal(clipped.rectangle_count(), 2)
    assert_true(clipped.rectangle(0).top() == 2.0)
    assert_true(clipped.rectangle(1).top() == 3.0)
    assert_true(clipped.bounds().x_min() == 0.0)
    assert_true(clipped.bounds().x_max() == 2.0)


def test_histogram_expands_constant_data_safely() raises:
    var data: List[Float64] = [5.0, 5.0]
    var figure = Figure()
    figure.histogram(data, bins=2)
    ref histogram = figure.rectangles(0)

    assert_true(histogram.bounds().x_min() == 4.0)
    assert_true(histogram.bounds().x_max() == 6.0)
    assert_true(histogram.rectangle(1).top() == 2.0)


def test_histogram_uses_its_exact_rendered_boundaries() raises:
    var lo = -10.0
    var hi = -9.6
    var boundary = 0.5 * lo + 0.5 * hi
    var data: List[Float64] = [lo, boundary, hi]
    var figure = Figure()
    figure.histogram(data, lo, hi, bins=2)
    ref histogram = figure.rectangles(0)

    assert_true(histogram.rectangle(0).right() == boundary)
    assert_true(histogram.rectangle(0).top() == 1.0)
    assert_true(histogram.rectangle(1).top() == 2.0)

    var subnormal = Float64("5e-324")
    var adjacent: List[Float64] = [0.0, subnormal]
    var one_bin = Figure()
    one_bin.histogram(adjacent, 0.0, subnormal, bins=1)
    assert_true(one_bin.rectangles(0).rectangle(0).top() == 2.0)
    with assert_raises(contains="is too narrow for 2 distinct bins"):
        one_bin.histogram(adjacent, 0.0, subnormal, bins=2)


def test_histogram_handles_the_full_finite_float_range() raises:
    var data: List[Float64] = [
        -Float64.MAX_FINITE,
        0.0,
        Float64.MAX_FINITE,
    ]
    var figure = Figure()
    figure.histogram(
        data,
        -Float64.MAX_FINITE,
        Float64.MAX_FINITE,
        bins=2,
    )
    ref histogram = figure.rectangles(0)

    assert_true(histogram.rectangle(0).left() == -Float64.MAX_FINITE)
    assert_true(histogram.rectangle(0).right() == 0.0)
    assert_true(histogram.rectangle(1).right() == Float64.MAX_FINITE)
    assert_true(histogram.rectangle(0).top() == 1.0)
    assert_true(histogram.rectangle(1).top() == 2.0)


def test_basic_plot_validation_is_atomic_and_actionable() raises:
    var x: List[Float64] = [0.0, 1.0]
    var y: List[Float64] = [1.0, 2.0]
    var one: List[Float64] = [0.5]
    var negative: List[Float64] = [0.5, -0.25]
    var nonfinite: List[Float64] = [0.0, Float64("nan"), Float64("inf"), 1.0]
    var figure = Figure()

    with assert_raises(contains="step x length 2 must equal y length 1"):
        figure.step(x, one)
    with assert_raises(contains="stem baseline must be finite; got nan"):
        figure.stem(x, y, baseline=Float64("nan"))
    with assert_raises(contains="y_error length 1 must equal coordinate length 2"):
        figure.errorbar(x, y, one)
    with assert_raises(contains="y_error at index 1 must be finite and non-negative"):
        figure.errorbar(x, y, negative)
    with assert_raises(contains="bar width must be finite and positive; got 0.0"):
        figure.bar(x, y, width=0.0)
    with assert_raises(contains="histogram bin count must be positive; got 0"):
        figure.histogram(y, bins=0)
    with assert_raises(contains="histogram data at index 1 must be finite; got nan"):
        figure.histogram(nonfinite, bins=2)
    with assert_raises(contains="histogram range must contain finite lo < hi"):
        figure.histogram(y, 2.0, 1.0)

    assert_equal(figure.line_count(), 0)
    assert_equal(figure.rectangle_count(), 0)


def test_svg_preserves_interleaved_order_labels_and_filled_bars() raises:
    var x: List[Float64] = [0.0, 1.0]
    var rising: List[Float64] = [0.0, 1.0]
    var categories: List[String] = ["A&B", "snow"]
    var heights: List[Float64] = [1.0, 2.0]
    var marker_x: List[Float64] = [0.5]
    var marker_y: List[Float64] = [0.5]
    var figure = Figure()
    figure.line(x, rising, label="line")
    figure.bar(categories, heights, label="bars")
    figure.scatter(marker_x, marker_y, label="point")

    var svg = render_svg(figure, 240.0, 160.0)
    var line = first_occurrence(svg, '<polyline class="sen-series-0" ')
    var bar = first_occurrence(svg, '<rect class="sen-series-1" ')
    var marker = first_occurrence(svg, '<circle class="sen-series-2" ')
    assert_true(line >= 0 and line < bar and bar < marker)
    assert_equal(count_occurrences(svg, '<rect class="sen-series-1" '), 2)
    assert_true('fill="#ff7f0e"' in svg)
    assert_true(">A&amp;B</text>" in svg)
    assert_true(">snow</text>" in svg)
    assert_equal(count_occurrences(svg, 'class="sen-legend-item"'), 6)


def test_log_axis_rejects_nonpositive_explicit_category_ticks() raises:
    var x: List[Float64] = [1.0, 10.0]
    var y: List[Float64] = [1.0, 2.0]
    var ticks: List[Float64] = [0.0, 1.0]
    var labels: List[String] = ["zero", "one"]
    var figure = Figure()
    figure.line(x, y)
    figure.set_x_ticks(ticks, labels)
    figure.set_x_scale(AxisKind.LOG10)

    with assert_raises(contains="log-scale x tick positions must be positive; tick 0"):
        _ = render_svg(figure)


def test_explicit_x_limits_filter_category_ticks_and_labels() raises:
    var categories: List[String] = ["outside-left", "inside", "outside-right"]
    var values: List[Float64] = [1.0, 2.0, 3.0]
    var figure = Figure()
    figure.bar(categories, values)
    figure.set_x_limits(0.5, 1.5)

    var svg = render_svg(figure, 240.0, 160.0)
    assert_true(">inside</text>" in svg)
    assert_true(">outside-left</text>" not in svg)
    assert_true(">outside-right</text>" not in svg)


def test_plot_facade_exposes_the_complete_basic_family() raises:
    var x: List[Float64] = [0.0, 1.0, 2.0]
    var y: List[Float64] = [1.0, 2.0, 1.0]
    var error: List[Float64] = [0.1, 0.2, 0.1]
    var plot = Plot()
    plot.step(x, y, mode=StepMode.POST)
    plot.stem(x, y, baseline=-1.0)
    plot.errorbar(x, y, error)
    plot.bar(x, y)
    plot.histogram(y, bins=2)

    var svg = plot.render_svg(240.0, 160.0)
    assert_equal(count_occurrences(svg, '<polyline class="sen-series-'), 7)
    assert_equal(count_occurrences(svg, '<rect class="sen-series-3" '), 3)
    assert_equal(count_occurrences(svg, '<rect class="sen-series-4" '), 2)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
