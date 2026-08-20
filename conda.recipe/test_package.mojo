from sen import Figure, LineSeries, PlotPoint
from std.testing import assert_true


def main() raises:
    var line = LineSeries()
    line.append(PlotPoint(4.0, -2.0))
    line.append(PlotPoint(-1.0, 3.0))
    var bounds = line.bounds()
    assert_true(bounds)
    assert_true(bounds.value().x_min() == -1.0)
    assert_true(bounds.value().x_max() == 4.0)
    assert_true(bounds.value().y_min() == -2.0)
    assert_true(bounds.value().y_max() == 3.0)
    var figure = Figure()
    figure.add_line(line)
    assert_true(figure.line_count() == 1)
