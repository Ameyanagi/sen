from sen import (
    AxisKind,
    CommandKind,
    Figure,
    LineStyle,
    Margins,
    MissingPolicy,
    Plot,
    SeriesStyle,
    build_render_plan,
    render_svg,
)
from std.collections import List
from std.testing import TestSuite, assert_equal, assert_raises, assert_true


def _fixture_margins() raises -> Margins:
    return Margins(24.0, 8.0, 8.0, 20.0)


def _area_figure() raises -> Figure:
    var x: List[Float64] = [0.0, 1.0, 2.0, 3.0]
    var y: List[Float64] = [1.0, 3.0, 2.0, 4.0]
    var figure = Figure()
    figure.area(x, y, baseline=0.0, label="signal")
    return figure^


def _read_fixture(path: StringSlice) raises -> String:
    with open(path, "r") as fixture:
        return fixture.read()


def _count(text: StringSlice, needle: StringSlice) -> Int:
    var count = 0
    var index = 0
    while index + needle.byte_length() <= text.byte_length():
        if text[byte = index : index + needle.byte_length()] == needle:
            count += 1
            index += needle.byte_length()
        else:
            index += 1
    return count


def _first(text: StringSlice, needle: StringSlice, start: Int = 0) -> Int:
    var index = start
    while index + needle.byte_length() <= text.byte_length():
        if text[byte = index : index + needle.byte_length()] == needle:
            return index
        index += 1
    return -1


def test_area_preserves_segments_and_includes_baseline_in_bounds() raises:
    var nan = Float64("nan")
    var x: List[Float64] = [0.0, 1.0, nan, 3.0, 4.0]
    var y: List[Float64] = [2.0, 3.0, nan, 4.0, 5.0]
    var figure = Figure()
    figure.area(
        x,
        y,
        baseline=-1.0,
        label="segmented",
        missing=MissingPolicy.SEGMENT,
    )

    assert_equal(figure.area_count(), 1)
    assert_equal(figure.area_label(0), "segmented")
    ref area = figure.area(0)
    assert_equal(area.segment_count(), 2)
    assert_equal(area.point_count(), 4)
    assert_true(area.baseline() == -1.0)
    assert_true(area.bounds().y_min() == -1.0)
    assert_true(area.bounds().y_max() == 5.0)


def test_area_validation_is_atomic_and_actionable() raises:
    var x: List[Float64] = [0.0, 1.0]
    var y: List[Float64] = [1.0, 2.0]
    var short: List[Float64] = [1.0]
    var figure = Figure()

    with assert_raises(contains="x and y coordinate sequences must have equal length"):
        figure.area(x, short)
    with assert_raises(contains="area baseline must be finite; got nan"):
        figure.area(x, y, baseline=Float64("nan"))
    assert_equal(figure.area_count(), 0)


def test_area_svg_is_byte_exact_and_uses_one_polygon() raises:
    var figure = _area_figure()
    var svg = render_svg(figure, 160.0, 100.0, _fixture_margins())

    assert_equal(svg, _read_fixture("tests/fixtures/area.svg"))
    assert_equal(_count(svg, '<polygon class="sen-series-0" '), 1)
    assert_true('fill-opacity="0.35"' in svg)
    assert_equal(_count(svg, 'class="sen-legend-item"'), 2)


def test_area_lowering_produces_backend_neutral_area_command() raises:
    var figure = _area_figure()
    var plan = build_render_plan(figure, 160.0, 100.0, _fixture_margins())
    var found_area = False
    for index in range(plan.command_count()):
        if plan.commands[index].kind._value == CommandKind.AREA._value:
            found_area = True
            assert_equal(len(plan.commands[index].points), 6)
    assert_true(found_area)


def test_segmented_area_renders_baseline_style_order_legend_and_clip() raises:
    var nan = Float64("nan")
    var line_x: List[Float64] = [0.0, 4.0]
    var line_y: List[Float64] = [0.5, 0.5]
    var area_x: List[Float64] = [0.0, 1.0, nan, 3.0, 4.0]
    var area_y: List[Float64] = [2.0, 3.0, nan, 4.0, 2.0]
    var marker_x: List[Float64] = [2.0]
    var marker_y: List[Float64] = [4.5]
    var area_style = SeriesStyle().with_line_width(2.5)
    area_style = area_style.with_line_style(LineStyle.DASHED)
    var figure = Figure()
    figure.line(line_x, line_y, label="line")
    figure.area(
        area_x,
        area_y,
        baseline=1.0,
        label="area",
        style=area_style,
        missing=MissingPolicy.SEGMENT,
    )
    figure.scatter(marker_x, marker_y, label="point")
    figure.set_x_limits(0.0, 4.0)
    figure.set_y_limits(0.0, 5.0)

    var svg = render_svg(figure, 160.0, 100.0, _fixture_margins())
    assert_equal(_count(svg, '<polygon class="sen-series-1" '), 2)
    assert_true('points="24,65.6 24,51.2 56,36.8 56,65.6"' in svg)
    assert_true('points="120,65.6 120,22.4 152,51.2 152,65.6"' in svg)
    # Both polygons and the legend glyph preserve the same area presentation.
    assert_equal(_count(svg, 'fill-opacity="0.35"'), 3)
    assert_equal(_count(svg, 'stroke-width="2.5"'), 3)
    assert_equal(_count(svg, 'stroke-dasharray="6 3"'), 3)

    var clip_open = _first(svg, '<g clip-path="url(#sen-plot-area)">')
    var line_position = _first(svg, 'class="sen-series-0"', clip_open)
    var first_area = _first(svg, 'class="sen-series-1"', line_position)
    var second_area = _first(svg, 'class="sen-series-1"', first_area + 1)
    var marker_position = _first(svg, 'class="sen-series-2"', second_area)
    var clip_close = _first(svg, "  </g>", marker_position)
    assert_true(
        clip_open >= 0
        and line_position > clip_open
        and first_area > line_position
        and second_area > first_area
        and marker_position > second_area
        and clip_close > marker_position
    )


def test_area_log_axis_rejects_nonpositive_baseline() raises:
    var figure = _area_figure()
    figure.set_y_scale(AxisKind.LOG10)
    with assert_raises(contains="log-scale y domain requires positive values"):
        _ = render_svg(figure)


def test_plot_area_keeps_the_simple_front_door() raises:
    var x: List[Float64] = [0.0, 1.0, 2.0]
    var y: List[Float64] = [1.0, 2.0, 1.0]
    var plot = Plot()
    plot.area(x, y, label="envelope")
    var svg = plot.render_svg(240.0, 160.0)
    assert_equal(_count(svg, '<polygon class="sen-series-0" '), 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
