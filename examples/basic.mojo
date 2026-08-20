from sen import Figure, LineSeries, PlotPoint


def main() raises:
    var line = LineSeries()
    line.append(PlotPoint(0.0, 1.0))
    line.append(PlotPoint(1.0, 3.0))
    # A missing observation breaks the line; its NaN is never stored.
    line.start_segment(PlotPoint(2.0, 2.0))
    var figure = Figure()
    figure.add_line(line)
    print("figure line series:", figure.line_count())
    print("connected segments:", figure.line(0).segment_count())
