from sen import (
    AxisKind,
    Figure,
    LegendPosition,
    Margins,
    Plot,
    render_svg,
)
from std.collections import List
from std.testing import TestSuite, assert_equal, assert_raises, assert_true


def test_plot_facade_matches_figure_rendering() raises:
    var x: List[Float64] = [1.0, 10.0, 100.0]
    var line_y: List[Float64] = [1.0, 10.0, 100.0]
    var scatter_y: List[Float64] = [2.0, 20.0, 80.0]

    var plot = Plot()
    plot.line(x, line_y, label="line")
    plot.scatter(x, scatter_y, label="samples")
    plot.title("Facade")
    plot.xlabel("input")
    plot.ylabel("response")
    plot.grid()
    plot.xscale(AxisKind.LOG10)
    plot.yscale(AxisKind.LOG10)
    plot.xlim(1.0, 100.0)
    plot.ylim(1.0, 100.0)
    plot.legend(LegendPosition.LOWER_LEFT)

    var figure = Figure()
    figure.line(x, line_y, label="line")
    figure.scatter(x, scatter_y, label="samples")
    figure.set_title("Facade")
    figure.set_x_label("input")
    figure.set_y_label("response")
    figure.set_grid(True)
    figure.set_x_scale(AxisKind.LOG10)
    figure.set_y_scale(AxisKind.LOG10)
    figure.set_x_limits(1.0, 100.0)
    figure.set_y_limits(1.0, 100.0)
    figure.set_legend(LegendPosition.LOWER_LEFT)

    var margins = Margins(24.0, 8.0, 8.0, 20.0)
    assert_equal(
        plot.render_svg(240.0, 160.0, margins),
        render_svg(figure, 240.0, 160.0, margins),
    )


def test_plot_forwards_validation_before_insertion() raises:
    var plot = Plot()
    var two: List[Float64] = [1.0, 2.0]
    var one: List[Float64] = [1.0]

    with assert_raises(contains="coordinate sequences must have equal length"):
        plot.line(two, one)
    with assert_raises(contains="x limits must satisfy lo < hi"):
        plot.xlim(2.0, 1.0)
    with assert_raises(contains="figure has no series"):
        _ = plot.render_svg()


def test_plot_save_svg_writes_exact_default_render() raises:
    var x: List[Float64] = [0.0, 1.0]
    var y: List[Float64] = [0.0, 1.0]
    var plot = Plot()
    plot.line(x, y)

    var path = String(".pixi/plot-facade-test.svg")
    plot.save_svg(path)
    with open(path, "r") as saved:
        assert_equal(saved.read(), plot.render_svg())


def test_plot_grid_and_legend_defaults_are_convenient() raises:
    var x: List[Float64] = [0.0, 1.0]
    var y: List[Float64] = [0.0, 1.0]
    var plot = Plot()
    plot.line(x, y, label="line")
    plot.grid()
    plot.legend()

    var svg = plot.render_svg()
    assert_true('class="sen-grid"' in svg)
    assert_true('class="sen-legend"' in svg)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
