from sen import (
    AxisKind,
    Figure,
    LineSeries,
    LineStyle,
    MarkerStyle,
    Margins,
    MissingPolicy,
    PlotPoint,
    SeriesStyle,
    render_svg,
    save_svg,
)
from std.collections import List


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


def segment_gap_figure() raises -> Figure:
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


def area_figure() raises -> Figure:
    var xs: List[Float64] = [0.0, 1.0, 2.0, 3.0]
    var ys: List[Float64] = [1.0, 3.0, 2.0, 4.0]
    var figure = Figure()
    figure.area(xs, ys, baseline=0.0, label="signal")
    return figure^


def main() raises:
    var margins = fixture_margins()
    var single = single_line_figure()
    save_svg(
        "tests/fixtures/single_line.svg",
        render_svg(single, 120.0, 80.0, margins),
    )
    var two = two_series_figure()
    save_svg(
        "tests/fixtures/two_series.svg",
        render_svg(two, 120.0, 80.0, margins),
    )
    var gap = segment_gap_figure()
    save_svg(
        "tests/fixtures/segment_gap.svg",
        render_svg(gap, 120.0, 80.0, margins),
    )
    var titled = titled_labels_figure()
    save_svg(
        "tests/fixtures/titled_labels.svg",
        render_svg(titled, 320.0, 200.0, margins),
    )
    var scatter = scatter_figure()
    save_svg(
        "tests/fixtures/scatter_basic.svg",
        render_svg(scatter, 120.0, 80.0, margins),
    )
    var missing = missing_segment_figure()
    save_svg(
        "tests/fixtures/missing_segment.svg",
        render_svg(missing, 120.0, 80.0, margins),
    )
    var styled = styled_series_figure()
    save_svg(
        "tests/fixtures/styled_series.svg",
        render_svg(styled, 160.0, 100.0, margins),
    )
    var markers = markers_figure()
    save_svg(
        "tests/fixtures/markers.svg",
        render_svg(markers, 240.0, 140.0, margins),
    )
    var legend = legend_figure()
    save_svg(
        "tests/fixtures/legend.svg",
        render_svg(legend, 240.0, 140.0, margins),
    )
    var grid = grid_figure()
    save_svg(
        "tests/fixtures/grid.svg",
        render_svg(grid, 200.0, 140.0, margins),
    )
    var limits = limits_figure()
    save_svg(
        "tests/fixtures/limits.svg",
        render_svg(limits, 200.0, 140.0, margins),
    )
    var semilog = semilog_decay_figure()
    save_svg(
        "tests/fixtures/semilog_decay.svg",
        render_svg(semilog, 200.0, 140.0, margins),
    )
    var area = area_figure()
    save_svg(
        "tests/fixtures/area.svg",
        render_svg(area, 160.0, 100.0, margins),
    )
    print("Regenerated 13 SVG fixtures under tests/fixtures/.")
