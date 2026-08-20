from sen import Figure, LineSeries, PlotPoint
from std.testing import assert_true


def main() raises:
    var line = LineSeries()
    line.append(PlotPoint(4.0, -2.0))
    line.start_segment(PlotPoint(-1.0, 3.0))
    assert_true(line.segment_count() == 2)
    assert_true(line.segment_point_count(0) == 1)
    assert_true(line.segment_point_count(1) == 1)
    var bounds = line.bounds()
    assert_true(bounds.x_min() == -1.0)
    assert_true(bounds.x_max() == 4.0)
    assert_true(bounds.y_min() == -2.0)
    assert_true(bounds.y_max() == 3.0)
    var figure = Figure()
    figure.add_line(line^)
    assert_true(figure.line_count() == 1)
