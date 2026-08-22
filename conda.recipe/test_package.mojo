from sen import Figure, LineSeries, Margins, Plot, PlotPoint, build_render_plan
from std.collections import List
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
    var plan = build_render_plan(figure, 240.0, 160.0, Margins(40.0, 12.0, 12.0, 28.0))
    plan.validate()
    assert_true(plan.command_count() > 0)

    var x: List[Float64] = [0.0, 1.0, 2.0]
    var y: List[Float64] = [1.0, 2.0, 1.0]
    var plot = Plot()
    plot.area(x, y, label="area")
    var svg = plot.render_svg(240.0, 160.0)
    assert_true('<polygon class="sen-series-0"' in svg)
