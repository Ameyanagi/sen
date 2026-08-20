from sen import Figure, LineSeries, PlotPoint, render_svg, save_svg
from std.os import makedirs


def main() raises:
    var line = LineSeries()
    line.append(PlotPoint(0.0, 1.0))
    line.append(PlotPoint(1.0, 3.0))
    # A missing observation breaks the line; its NaN is never stored.
    line.start_segment(PlotPoint(2.0, 2.0))
    var figure = Figure()
    figure.add_line(line^)
    makedirs("output", exist_ok=True)
    var svg = render_svg(figure, 640.0, 480.0)
    save_svg("output/basic.svg", svg)
    print("Wrote output/basic.svg")
