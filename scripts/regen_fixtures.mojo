from sen import (
    Figure,
    LineSeries,
    Margins,
    MissingPolicy,
    PlotPoint,
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
        render_svg(titled, 120.0, 80.0, margins),
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
    print("Regenerated 6 SVG fixtures under tests/fixtures/.")
