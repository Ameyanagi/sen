from sen import (
    AxisKind,
    Figure,
    LegendPosition,
    LineSeries,
    LineStyle,
    MarkerStyle,
    Margins,
    MissingPolicy,
    PlotPoint,
    SeriesStyle,
    render_svg,
)
from sen.svg import _escape_xml, _format_decimal, _format_svg_number, _tick_label
from std.collections import List
from std.pathlib import Path
from std.testing import TestSuite, assert_equal, assert_raises, assert_true


def fixture_margins() raises -> Margins:
    return Margins(24.0, 8.0, 8.0, 20.0)


def single_line_figure() raises -> Figure:
    var line = LineSeries()
    line.append(PlotPoint(0.0, 0.0))
    line.append(PlotPoint(1.0, 1.0))
    line.append(PlotPoint(2.0, 0.0))
    var figure = Figure()
    figure.add_line(line^)
    return figure^


def two_series_figure() raises -> Figure:
    var rising = LineSeries()
    rising.append(PlotPoint(0.0, 0.0))
    rising.append(PlotPoint(2.0, 2.0))
    var falling = LineSeries()
    falling.append(PlotPoint(0.0, 2.0))
    falling.append(PlotPoint(2.0, 0.0))
    var figure = Figure()
    figure.add_line(rising^)
    figure.add_line(falling^)
    return figure^


def gap_figure() raises -> Figure:
    var line = LineSeries()
    line.append(PlotPoint(0.0, 0.0))
    line.append(PlotPoint(1.0, 1.0))
    line.start_segment(PlotPoint(2.0, 1.0))
    line.append(PlotPoint(3.0, 0.0))
    var figure = Figure()
    figure.add_line(line^)
    return figure^


def titled_labels_figure() raises -> Figure:
    var xs: List[Float64] = [0.0, 1.0, 2.0]
    var ys: List[Float64] = [0.0, 1.0, 0.0]
    var figure = Figure()
    figure.line(xs, ys)
    figure.set_title("Deterministic <plot>")
    figure.set_x_label("x & time")
    figure.set_y_label("value 'y'")
    return figure^


def scatter_figure() raises -> Figure:
    var xs: List[Float64] = [0.0, 0.5, 1.0, 1.5, 2.0]
    var ys: List[Float64] = [0.0, 0.5, 1.0, 0.5, 0.0]
    var figure = Figure()
    figure.scatter(xs, ys)
    return figure^


def missing_segment_figure() raises -> Figure:
    var nan = Float64("nan")
    var xs: List[Float64] = [0.0, 1.0, nan, nan, 3.0, 4.0]
    var ys: List[Float64] = [0.0, 1.0, nan, 0.5, 1.0, 0.0]
    var figure = Figure()
    figure.line(xs, ys, missing=MissingPolicy.SEGMENT)
    return figure^


def styled_series_figure() raises -> Figure:
    var xs: List[Float64] = [0.0, 1.0, 2.0]
    var first_y: List[Float64] = [0.0, 1.0, 0.0]
    var second_y: List[Float64] = [1.0, 2.0, 1.0]
    var third_y: List[Float64] = [2.0, 3.0, 2.0]
    var marker_x: List[Float64] = [1.5]
    var marker_y: List[Float64] = [1.5]

    var dashed = SeriesStyle()
    dashed = dashed.with_line_style(LineStyle.DASHED)
    dashed = dashed.with_line_width(2.5)
    var dotted = SeriesStyle(color_index=4)
    dotted = dotted.with_line_style(LineStyle.DOTTED)

    var figure = Figure()
    figure.line(xs, first_y)
    figure.line(xs, second_y, style=dashed)
    figure.line(xs, third_y, style=dotted)
    figure.scatter(marker_x, marker_y)
    return figure^


def markers_figure() raises -> Figure:
    var markers: List[MarkerStyle] = [
        MarkerStyle.CIRCLE,
        MarkerStyle.SQUARE,
        MarkerStyle.TRIANGLE,
        MarkerStyle.DIAMOND,
        MarkerStyle.PLUS,
        MarkerStyle.CROSS,
        MarkerStyle.STAR,
    ]
    var figure = Figure()
    for index in range(len(markers)):
        var xs: List[Float64] = [Float64(index)]
        var ys: List[Float64] = [Float64(index % 2)]
        var style = SeriesStyle().with_marker_style(markers[index])
        figure.scatter(xs, ys, style=style)
    return figure^


def legend_figure() raises -> Figure:
    var xs: List[Float64] = [0.0, 1.0, 2.0]
    var first_y: List[Float64] = [0.0, 1.0, 0.5]
    var second_y: List[Float64] = [1.5, 0.5, 1.0]
    var marker_x: List[Float64] = [1.0]
    var marker_y: List[Float64] = [1.25]
    var dashed = SeriesStyle().with_line_style(LineStyle.DASHED)
    var square = SeriesStyle().with_marker_style(MarkerStyle.SQUARE)
    var figure = Figure()
    figure.line(xs, first_y, label="observed")
    figure.line(xs, second_y, label="forecast", style=dashed)
    figure.scatter(marker_x, marker_y, label="sample & hold", style=square)
    return figure^


def grid_figure() raises -> Figure:
    var figure = single_line_figure()
    figure.set_grid(True)
    return figure^


def limits_figure() raises -> Figure:
    var xs: List[Float64] = [-5.0, 0.0, 10.0, 15.0]
    var ys: List[Float64] = [-5.0, 0.0, 10.0, 15.0]
    var figure = Figure()
    figure.line(xs, ys)
    figure.set_x_limits(0.0, 10.0)
    figure.set_y_limits(0.0, 10.0)
    return figure^


def semilog_decay_figure() raises -> Figure:
    var xs: List[Float64] = [0.0, 1.0, 2.0, 3.0, 4.0]
    var ys: List[Float64] = [1000.0, 100.0, 10.0, 1.0, 0.1]
    var figure = Figure()
    figure.line(xs, ys)
    figure.set_y_scale(AxisKind.LOG10)
    figure.set_grid(True)
    return figure^


def read_fixture(path: StringSlice) raises -> String:
    with open(path, "r") as fixture:
        return fixture.read()


def count_occurrences(text: StringSlice, needle: StringSlice) -> Int:
    var count = 0
    var index = 0
    while index + needle.byte_length() <= text.byte_length():
        if text[byte = index : index + needle.byte_length()] == needle:
            count += 1
            index += needle.byte_length()
        else:
            index += 1
    return count


def first_occurrence(text: StringSlice, needle: StringSlice, start: Int = 0) -> Int:
    var index = start
    while index + needle.byte_length() <= text.byte_length():
        if text[byte = index : index + needle.byte_length()] == needle:
            return index
        index += 1
    return -1


def test_single_line_golden_fixture_is_byte_exact() raises:
    var figure = single_line_figure()
    var actual = render_svg(figure, 120.0, 80.0, fixture_margins())
    assert_equal(actual, read_fixture("tests/fixtures/single_line.svg"))


def test_two_series_golden_fixture_is_byte_exact() raises:
    var figure = two_series_figure()
    var actual = render_svg(figure, 120.0, 80.0, fixture_margins())
    assert_equal(actual, read_fixture("tests/fixtures/two_series.svg"))


def test_gap_golden_fixture_is_byte_exact() raises:
    var figure = gap_figure()
    var actual = render_svg(figure, 120.0, 80.0, fixture_margins())
    assert_equal(actual, read_fixture("tests/fixtures/segment_gap.svg"))


def test_titled_labels_golden_fixture_is_byte_exact() raises:
    var figure = titled_labels_figure()
    var actual = render_svg(figure, 120.0, 80.0, fixture_margins())
    assert_equal(actual, read_fixture("tests/fixtures/titled_labels.svg"))


def test_scatter_golden_fixture_is_byte_exact() raises:
    var figure = scatter_figure()
    var actual = render_svg(figure, 120.0, 80.0, fixture_margins())
    assert_equal(actual, read_fixture("tests/fixtures/scatter_basic.svg"))


def test_missing_segment_golden_fixture_is_byte_exact() raises:
    var figure = missing_segment_figure()
    var actual = render_svg(figure, 120.0, 80.0, fixture_margins())
    assert_equal(actual, read_fixture("tests/fixtures/missing_segment.svg"))


def test_styled_series_golden_fixture_is_byte_exact() raises:
    var figure = styled_series_figure()
    var actual = render_svg(figure, 160.0, 100.0, fixture_margins())
    assert_equal(actual, read_fixture("tests/fixtures/styled_series.svg"))


def test_markers_golden_fixture_is_byte_exact() raises:
    var figure = markers_figure()
    var actual = render_svg(figure, 240.0, 140.0, fixture_margins())
    assert_equal(actual, read_fixture("tests/fixtures/markers.svg"))


def test_legend_golden_fixture_is_byte_exact() raises:
    var figure = legend_figure()
    var actual = render_svg(figure, 240.0, 140.0, fixture_margins())
    assert_equal(actual, read_fixture("tests/fixtures/legend.svg"))


def test_grid_golden_fixture_is_byte_exact() raises:
    var figure = grid_figure()
    var actual = render_svg(figure, 200.0, 140.0, fixture_margins())
    assert_equal(actual, read_fixture("tests/fixtures/grid.svg"))


def test_limits_golden_fixture_is_byte_exact() raises:
    var figure = limits_figure()
    var actual = render_svg(figure, 200.0, 140.0, fixture_margins())
    assert_equal(actual, read_fixture("tests/fixtures/limits.svg"))


def test_semilog_decay_golden_fixture_is_byte_exact() raises:
    var figure = semilog_decay_figure()
    var actual = render_svg(figure, 200.0, 140.0, fixture_margins())
    assert_equal(actual, read_fixture("tests/fixtures/semilog_decay.svg"))


def test_log_axis_reports_series_and_offending_bound() raises:
    var positive_xs: List[Float64] = [1.0, 2.0]
    var negative_xs: List[Float64] = [-0.2, 3.0]
    var ys: List[Float64] = [1.0, 2.0]
    var figure = Figure()
    figure.line(positive_xs, ys)
    figure.scatter(negative_xs, ys)
    figure.set_x_scale(AxisKind.LOG10)

    with assert_raises(
        contains=(
            "log-scale x domain requires positive values; series 1 has x_min = -0.2"
        )
    ):
        _ = render_svg(figure, 200.0, 140.0, fixture_margins())


def test_log_axis_reports_nonpositive_explicit_limit() raises:
    var xs: List[Float64] = [1.0, 10.0]
    var ys: List[Float64] = [1.0, 2.0]
    var figure = Figure()
    figure.line(xs, ys)
    figure.set_x_scale(AxisKind.LOG10)
    figure.set_x_limits(0.0, 10.0)

    with assert_raises(
        contains="log-scale x domain requires positive values; explicit x limit lo = 0"
    ):
        _ = render_svg(figure, 200.0, 140.0, fixture_margins())


def test_semantic_css_classes_are_first_attributes() raises:
    var figure = legend_figure()
    figure.set_title("classes")
    figure.set_x_label("x")
    figure.set_y_label("y")
    figure.set_grid(True)
    var svg = render_svg(figure, 240.0, 140.0, fixture_margins())

    assert_true(count_occurrences(svg, '<rect class="sen-background" ') > 0)
    assert_true(count_occurrences(svg, '<rect class="sen-frame" ') > 0)
    assert_true(count_occurrences(svg, '<line class="sen-axis" ') > 0)
    assert_true(count_occurrences(svg, '<line class="sen-tick" ') > 0)
    assert_true(count_occurrences(svg, '<text class="sen-tick-label" ') > 0)
    assert_true(count_occurrences(svg, '<text class="sen-title" ') > 0)
    assert_true(count_occurrences(svg, '<text class="sen-x-label" ') > 0)
    assert_true(count_occurrences(svg, '<text class="sen-y-label" ') > 0)
    assert_true(count_occurrences(svg, '<line class="sen-grid" ') > 0)
    assert_true(count_occurrences(svg, '<polyline class="sen-series-0" ') > 0)
    assert_true(count_occurrences(svg, '<polyline class="sen-series-1" ') > 0)
    assert_true(count_occurrences(svg, '<rect class="sen-series-2" ') > 0)
    assert_true(count_occurrences(svg, '<rect class="sen-legend" ') > 0)
    assert_true(count_occurrences(svg, '<line class="sen-legend-item" ') > 0)
    assert_true(count_occurrences(svg, '<text class="sen-legend-item" ') > 0)


def test_xml_escape_covers_predefined_entities_and_unicode() raises:
    assert_equal(
        _escape_xml("A&B <tag> \"quote\" 'apostrophe' 雪"),
        "A&amp;B &lt;tag&gt; &quot;quote&quot; &apos;apostrophe&apos; 雪",
    )


def test_fixed_decimal_formatting_rules() raises:
    assert_equal(_format_decimal(1.2345, 3), "1.235")
    assert_equal(_format_decimal(-1.2345, 3), "-1.235")
    assert_equal(_format_svg_number(12.3401), "12.34")
    assert_equal(_format_svg_number(8.0), "8")
    assert_equal(_format_svg_number(-0.0004), "0")
    assert_equal(_format_svg_number(-0.0005), "-0.001")
    with assert_raises(contains="SVG numbers must be finite"):
        _ = _format_svg_number(Float64("nan"))


def test_tick_labels_follow_step_magnitude() raises:
    assert_equal(_tick_label(0.2, 0.2), "0.2")
    assert_equal(_tick_label(400000000.0, 200000000.0), "400000000")
    assert_equal(_tick_label(0.0000004, 0.0000002), "4e-7")


def test_rendering_is_deterministic_and_flips_y_coordinates() raises:
    var figure = single_line_figure()
    var first = render_svg(figure, 120.0, 80.0, fixture_margins())
    var second = render_svg(figure, 120.0, 80.0, fixture_margins())

    assert_equal(first, second)
    assert_equal(count_occurrences(first, "<polyline "), 1)
    assert_equal(
        count_occurrences(first, 'points="28,57.636 68,10.364 108,57.636"'),
        1,
    )
    assert_true(first.endswith("</svg>\n"))
    assert_true(not first.endswith("</svg>\n\n"))


def test_segment_gaps_emit_one_polyline_per_connected_segment() raises:
    var figure = gap_figure()
    var svg = render_svg(figure, 120.0, 80.0, fixture_margins())
    assert_equal(count_occurrences(svg, "<polyline "), 2)


def test_render_rejects_figures_without_points() raises:
    var empty = Figure()
    with assert_raises(
        contains=(
            "figure has no series; add data with line() or scatter() before rendering"
        )
    ):
        _ = render_svg(empty, 120.0, 80.0)

    var coordinates = List[Float64]()
    var only_empty_series = Figure()
    only_empty_series.line(coordinates, coordinates)
    with assert_raises(
        contains="figure has 1 series but all are empty; add points before rendering"
    ):
        _ = render_svg(only_empty_series, 120.0, 80.0)


def test_constant_domains_use_documented_padding() raises:
    var line = LineSeries()
    line.append(PlotPoint(2.0, -4.0))
    var figure = Figure()
    figure.add_line(line^)
    var svg = render_svg(figure, 120.0, 80.0, fixture_margins())

    assert_equal(count_occurrences(svg, "<polyline "), 1)
    assert_equal(count_occurrences(svg, 'points="68,34"'), 1)


def test_constant_log_domain_pads_one_decade_on_each_side() raises:
    var xs: List[Float64] = [2.0]
    var ys: List[Float64] = [10.0]
    var figure = Figure()
    figure.line(xs, ys)
    figure.set_y_scale(AxisKind.LOG10)
    var svg = render_svg(figure, 120.0, 80.0, fixture_margins())

    assert_equal(count_occurrences(svg, 'points="68,34"'), 1)


def test_every_marker_shape_uses_its_fixed_svg_element() raises:
    var figure = markers_figure()
    var svg = render_svg(figure, 240.0, 140.0, fixture_margins())

    assert_equal(count_occurrences(svg, "<circle "), 1)
    assert_equal(count_occurrences(svg, 'width="5" height="5" fill="#ff7f0e"'), 1)
    assert_equal(count_occurrences(svg, "<polygon "), 3)
    assert_equal(count_occurrences(svg, 'fill="#2ca02c"'), 1)
    assert_equal(count_occurrences(svg, 'fill="#d62728"'), 1)
    assert_equal(count_occurrences(svg, 'stroke="#9467bd" stroke-width="1.5"'), 2)
    assert_equal(count_occurrences(svg, 'stroke="#8c564b" stroke-width="1.5"'), 2)
    assert_equal(count_occurrences(svg, 'fill="#1f77b4"'), 2)


def test_none_marker_on_scatter_falls_back_to_circle() raises:
    var xs: List[Float64] = [0.0]
    var ys: List[Float64] = [0.0]
    var style = SeriesStyle().with_marker_style(MarkerStyle.NONE)
    var figure = Figure()
    figure.scatter(xs, ys, style=style)

    var svg = render_svg(figure, 120.0, 80.0, fixture_margins())
    assert_equal(count_occurrences(svg, "<circle "), 1)
    assert_equal(count_occurrences(svg, 'r="2.5" fill="#1f77b4"'), 1)


def test_legend_trigger_rule_and_suppression() raises:
    var unlabeled = single_line_figure()
    var without_legend = render_svg(unlabeled, 200.0, 140.0, fixture_margins())
    assert_equal(
        count_occurrences(without_legend, 'fill="#ffffff" stroke="#d0d0d0"'),
        0,
    )

    var xs: List[Float64] = [0.0, 1.0]
    var ys: List[Float64] = [0.0, 1.0]
    var suppressed = Figure()
    suppressed.line(xs, ys, label="visible label")
    suppressed.set_legend(LegendPosition.NONE)
    var svg = render_svg(suppressed, 200.0, 140.0, fixture_margins())
    assert_equal(count_occurrences(svg, ">visible label</text>"), 0)
    assert_equal(count_occurrences(svg, 'fill="#ffffff" stroke="#d0d0d0"'), 0)


def test_legend_positions_use_the_requested_plot_corner() raises:
    var xs: List[Float64] = [0.0, 1.0]
    var ys: List[Float64] = [0.0, 1.0]
    var figure = Figure()
    figure.line(xs, ys, label="a")

    var upper_right = render_svg(figure, 200.0, 140.0, fixture_margins())
    assert_equal(
        count_occurrences(
            upper_right,
            '<rect class="sen-legend" x="146" y="16" width="38" height="24"',
        ),
        1,
    )

    figure.set_legend(LegendPosition.UPPER_LEFT)
    var upper_left = render_svg(figure, 200.0, 140.0, fixture_margins())
    assert_equal(
        count_occurrences(
            upper_left,
            '<rect class="sen-legend" x="32" y="16" width="38" height="24"',
        ),
        1,
    )

    figure.set_legend(LegendPosition.LOWER_LEFT)
    var lower_left = render_svg(figure, 200.0, 140.0, fixture_margins())
    assert_equal(
        count_occurrences(
            lower_left,
            '<rect class="sen-legend" x="32" y="88" width="38" height="24"',
        ),
        1,
    )

    figure.set_legend(LegendPosition.LOWER_RIGHT)
    var lower_right = render_svg(figure, 200.0, 140.0, fixture_margins())
    assert_equal(
        count_occurrences(
            lower_right,
            '<rect class="sen-legend" x="146" y="88" width="38" height="24"',
        ),
        1,
    )


def test_legend_is_escaped_styled_and_drawn_after_series() raises:
    var figure = legend_figure()
    var svg = render_svg(figure, 240.0, 140.0, fixture_margins())
    var series_end = first_occurrence(svg, "  </g>")
    var legend_rect = first_occurrence(svg, 'fill="#ffffff" stroke="#d0d0d0"')

    assert_true(series_end >= 0)
    assert_true(series_end < legend_rect)
    assert_equal(count_occurrences(svg, ">sample &amp; hold</text>"), 1)
    assert_equal(count_occurrences(svg, 'stroke-dasharray="6 3"'), 2)
    assert_equal(count_occurrences(svg, 'font-size="8" text-anchor="start"'), 3)
    assert_equal(count_occurrences(svg, 'width="5" height="5" fill="#2ca02c"'), 2)


def test_grid_is_off_by_default_and_on_behind_axes_and_series() raises:
    var off = single_line_figure()
    var without_grid = render_svg(off, 200.0, 140.0, fixture_margins())
    assert_equal(count_occurrences(without_grid, "#e0e0e0"), 0)

    var on = grid_figure()
    var svg = render_svg(on, 200.0, 140.0, fixture_margins())
    var frame = first_occurrence(svg, 'stroke="#d0d0d0"')
    var grid = first_occurrence(svg, 'stroke="#e0e0e0"')
    var axis = first_occurrence(svg, 'stroke="#222222"')
    var series = first_occurrence(svg, "<g clip-path=")
    assert_true(frame < grid)
    assert_true(grid < axis)
    assert_true(axis < series)


def test_explicit_limits_define_exact_ticks_and_clipped_geometry() raises:
    var figure = limits_figure()
    var svg = render_svg(figure, 200.0, 140.0, fixture_margins())

    assert_equal(count_occurrences(svg, 'points="-60,176 24,120 192,8 276,-48"'), 1)
    assert_equal(
        count_occurrences(
            svg, '<line class="sen-tick" x1="24" y1="120" x2="24" y2="124"'
        ),
        1,
    )
    assert_equal(
        count_occurrences(
            svg,
            '<line class="sen-tick" x1="192" y1="120" x2="192" y2="124"',
        ),
        1,
    )
    assert_equal(count_occurrences(svg, '<clipPath id="sen-plot-area">'), 1)
    assert_equal(count_occurrences(svg, '<g clip-path="url(#sen-plot-area)">'), 1)


def test_one_explicit_axis_leaves_the_other_axis_autoscaled() raises:
    var xs: List[Float64] = [-5.0, 0.0, 10.0, 15.0]
    var ys: List[Float64] = [-5.0, 0.0, 10.0, 15.0]
    var figure = Figure()
    figure.line(xs, ys)
    figure.set_x_limits(0.0, 10.0)

    var svg = render_svg(figure, 200.0, 140.0, fixture_margins())
    assert_equal(
        count_occurrences(svg, 'points="-60,114.909 24,89.455 192,38.545 276,13.091"'),
        1,
    )


def test_lines_and_scatters_render_in_interleaved_insertion_order() raises:
    var xs: List[Float64] = [0.0, 1.0]
    var rising: List[Float64] = [0.0, 1.0]
    var falling: List[Float64] = [1.0, 0.0]
    var marker_x: List[Float64] = [0.5]
    var marker_y: List[Float64] = [0.5]
    var figure = Figure()
    figure.line(xs, rising)
    figure.scatter(marker_x, marker_y)
    figure.line(xs, falling)

    var svg = render_svg(figure, 120.0, 80.0, fixture_margins())
    var first_line = first_occurrence(svg, "<polyline ")
    var marker = first_occurrence(svg, "<circle ")
    var second_line = first_occurrence(svg, "<polyline ", first_line + 1)

    assert_true(first_line >= 0)
    assert_true(first_line < marker)
    assert_true(marker < second_line)


def test_auto_colors_follow_interleaved_series_insertion_order() raises:
    var xs: List[Float64] = [0.0, 1.0]
    var ys: List[Float64] = [0.0, 1.0]
    var figure = Figure()
    figure.line(xs, ys)
    figure.scatter(xs, ys)

    var svg = render_svg(figure, 120.0, 80.0, fixture_margins())
    var blue = first_occurrence(svg, "#1f77b4")
    var orange = first_occurrence(svg, "#ff7f0e")
    assert_true(blue >= 0)
    assert_true(blue < orange)


def test_explicit_color_does_not_advance_auto_palette_counter() raises:
    var xs: List[Float64] = [0.0, 1.0]
    var ys: List[Float64] = [0.0, 1.0]
    var figure = Figure()
    figure.line(xs, ys)
    figure.line(xs, ys, style=SeriesStyle(color_index=4))
    figure.scatter(xs, ys)

    var svg = render_svg(figure, 120.0, 80.0, fixture_margins())
    var blue = first_occurrence(svg, "#1f77b4")
    var purple = first_occurrence(svg, "#9467bd")
    var orange = first_occurrence(svg, "#ff7f0e")
    assert_true(blue >= 0)
    assert_true(blue < purple)
    assert_true(purple < orange)


def test_custom_colors_cover_series_legends_and_skip_auto_counter() raises:
    var xs: List[Float64] = [0.0, 1.0]
    var ys: List[Float64] = [0.0, 1.0]
    var line_style = SeriesStyle(color_index=4).with_color("#8B1E3F")
    var scatter_style = SeriesStyle(color="#2468AC")
    var figure = Figure()
    figure.line(xs, ys, label="custom line", style=line_style)
    figure.scatter(xs, ys, label="custom scatter", style=scatter_style)
    figure.line(xs, ys)

    var svg = render_svg(figure, 200.0, 140.0, fixture_margins())
    assert_equal(count_occurrences(svg, 'stroke="#8b1e3f"'), 2)
    assert_equal(count_occurrences(svg, 'fill="#2468ac"'), 3)
    assert_equal(count_occurrences(svg, 'stroke="#1f77b4"'), 1)
    assert_equal(count_occurrences(svg, "#9467bd"), 0)
    assert_equal(count_occurrences(svg, "#ff7f0e"), 0)


def test_add_line_label_produces_legend_entry() raises:
    var line = LineSeries()
    line.append(PlotPoint(0.0, 0.0))
    line.append(PlotPoint(1.0, 1.0))
    var figure = Figure()
    figure.add_line(line^, label="owned line")

    assert_equal(figure.line_label(0), "owned line")
    var svg = render_svg(figure, 200.0, 140.0, fixture_margins())
    assert_equal(count_occurrences(svg, ">owned line</text>"), 1)


def test_figure_save_svg_accepts_size_and_creates_parent_directories() raises:
    var figure = single_line_figure()
    var path = String(".pixi/test-files/sen-save-svg/nested/figure.svg")

    figure.save_svg(path, 160.0, 100.0)

    assert_true(Path(path).exists())
    assert_equal(Path(path).read_text(), render_svg(figure, 160.0, 100.0))


def test_line_dasharrays_and_widths_use_fixed_svg_attributes() raises:
    var xs: List[Float64] = [0.0, 1.0]
    var ys: List[Float64] = [0.0, 1.0]
    var dashed = SeriesStyle()
    dashed = dashed.with_line_style(LineStyle.DASHED)
    var dotted = SeriesStyle()
    dotted = dotted.with_line_style(LineStyle.DOTTED)
    var dash_dot = SeriesStyle()
    dash_dot = dash_dot.with_line_style(LineStyle.DASH_DOT)
    var figure = Figure()
    figure.line(xs, ys)
    figure.line(xs, ys, style=dashed)
    figure.line(xs, ys, style=dotted)
    figure.line(xs, ys, style=dash_dot)

    var svg = render_svg(figure, 120.0, 80.0, fixture_margins())
    assert_equal(count_occurrences(svg, "stroke-dasharray="), 3)
    assert_equal(count_occurrences(svg, 'stroke-dasharray="6 3"'), 1)
    assert_equal(count_occurrences(svg, 'stroke-dasharray="1.5 2.5"'), 1)
    assert_equal(count_occurrences(svg, 'stroke-dasharray="6 3 1.5 3"'), 1)
    assert_equal(
        count_occurrences(svg, 'stroke="#1f77b4" stroke-width="1.5"/>'),
        1,
    )


def test_title_and_axis_labels_are_escaped_and_use_fixed_geometry() raises:
    var figure = titled_labels_figure()
    var svg = render_svg(figure, 120.0, 80.0, fixture_margins())

    assert_equal(count_occurrences(svg, ">Deterministic &lt;plot&gt;</text>"), 1)
    assert_equal(count_occurrences(svg, ">x &amp; time</text>"), 1)
    assert_equal(count_occurrences(svg, ">value &apos;y&apos;</text>"), 1)
    assert_equal(count_occurrences(svg, 'font-size="12" text-anchor="middle"'), 1)
    assert_equal(count_occurrences(svg, 'font-size="10" text-anchor="middle"'), 2)
    assert_equal(count_occurrences(svg, 'transform="rotate(-90 '), 1)


def test_default_render_size_is_640_by_480() raises:
    var figure = single_line_figure()
    var svg = render_svg(figure)

    assert_true(
        svg.startswith(
            '<svg xmlns="http://www.w3.org/2000/svg" width="640" height="480"'
        )
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
