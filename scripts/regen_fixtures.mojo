from sen import Figure, LineSeries, Margins, PlotPoint, render_svg, save_svg


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
    print("Regenerated 3 SVG fixtures under tests/fixtures/.")
