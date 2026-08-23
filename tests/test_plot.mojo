from sen import (
    AxisKind,
    Figure,
    LegendPosition,
    Margins,
    MissingPolicy,
    Plot,
    SeriesStyle,
    StepMode,
    build_render_plan,
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


def test_fluent_plot_is_byte_identical_for_every_overload() raises:
    var x: List[Float64] = [0.0, 1.0, 2.0]
    var y: List[Float64] = [1.0, 2.0, 1.5]
    var x_error: List[Float64] = [0.1, 0.2, 0.1]
    var y_error: List[Float64] = [0.2, 0.1, 0.3]
    var categories: List[String] = ["zero", "one", "two"]
    var samples: List[Float64] = [0.0, 0.2, 0.8, 1.2, 1.8, 2.0]
    var style = SeriesStyle(color="#336699")

    var legacy = Plot()
    legacy.line(
        x,
        y,
        label="line",
        style=style,
        missing=MissingPolicy.DROP,
    )
    legacy.scatter(
        x,
        y,
        label="scatter",
        style=style,
        missing=MissingPolicy.SEGMENT,
    )
    legacy.area(
        x,
        y,
        baseline=-0.25,
        label="area",
        style=style,
        missing=MissingPolicy.DROP,
    )
    legacy.step(x, y, mode=StepMode.MID, label="step", style=style)
    legacy.stem(x, y, baseline=-0.5, label="stem", style=style)
    legacy.errorbar(
        x,
        y,
        y_error,
        cap_size=0.15,
        label="vertical errors",
        style=style,
    )
    legacy.errorbar(
        x,
        y,
        x_error,
        y_error,
        cap_size=0.2,
        label="both errors",
        style=style,
    )
    legacy.bar(
        x,
        y,
        width=0.5,
        baseline=-0.5,
        label="numeric bars",
        style=style,
    )
    legacy.bar(
        categories,
        y,
        width=0.6,
        baseline=-0.25,
        label="category bars",
        style=style,
    )
    legacy.histogram(samples, bins=4, label="observed histogram", style=style)
    legacy.histogram(
        samples,
        -1.0,
        3.0,
        bins=5,
        label="ranged histogram",
        style=style,
    )
    legacy.title("Every Plot overload")
    legacy.xlabel("input")
    legacy.ylabel("response")
    legacy.grid()
    legacy.xscale(AxisKind.LINEAR)
    legacy.yscale(AxisKind.LINEAR)
    legacy.xlim(-1.0, 3.0)
    legacy.ylim(-1.0, 3.0)
    legacy.legend(LegendPosition.LOWER_LEFT)

    var fluent = (
        Plot()
        .with_line(
            x,
            y,
            label="line",
            style=style,
            missing=MissingPolicy.DROP,
        )
        .with_scatter(
            x,
            y,
            label="scatter",
            style=style,
            missing=MissingPolicy.SEGMENT,
        )
        .with_area(
            x,
            y,
            baseline=-0.25,
            label="area",
            style=style,
            missing=MissingPolicy.DROP,
        )
        .with_step(x, y, mode=StepMode.MID, label="step", style=style)
        .with_stem(x, y, baseline=-0.5, label="stem", style=style)
        .with_errorbar(
            x,
            y,
            y_error,
            cap_size=0.15,
            label="vertical errors",
            style=style,
        )
        .with_errorbar(
            x,
            y,
            x_error,
            y_error,
            cap_size=0.2,
            label="both errors",
            style=style,
        )
        .with_bar(
            x,
            y,
            width=0.5,
            baseline=-0.5,
            label="numeric bars",
            style=style,
        )
        .with_bar(
            categories,
            y,
            width=0.6,
            baseline=-0.25,
            label="category bars",
            style=style,
        )
        .with_histogram(samples, bins=4, label="observed histogram", style=style)
        .with_histogram(
            samples,
            -1.0,
            3.0,
            bins=5,
            label="ranged histogram",
            style=style,
        )
        .with_title("Every Plot overload")
        .with_xlabel("input")
        .with_ylabel("response")
        .with_grid()
        .with_xscale(AxisKind.LINEAR)
        .with_yscale(AxisKind.LINEAR)
        .with_xlim(-1.0, 3.0)
        .with_ylim(-1.0, 3.0)
        .with_legend(LegendPosition.LOWER_LEFT)
    )

    var margins = Margins(32.0, 12.0, 12.0, 28.0)
    assert_equal(
        fluent.render_svg(480.0, 320.0, margins),
        legacy.render_svg(480.0, 320.0, margins),
    )


def test_fluent_plot_supports_direct_render_and_defaults() raises:
    var x: List[Float64] = [0.0, 1.0]
    var y: List[Float64] = [1.0, 2.0]
    var svg = (
        Plot()
        .with_line(x, y, label="line")
        .with_scatter(x, y, label="samples")
        .with_title("Fluent")
        .with_grid()
        .with_legend()
        .render_svg()
    )
    assert_true('<text class="sen-title"' in svg)
    assert_true('class="sen-grid"' in svg)
    assert_true('class="sen-legend"' in svg)


def test_fluent_plot_preserves_validation_errors() raises:
    var two: List[Float64] = [1.0, 2.0]
    var one: List[Float64] = [1.0]

    with assert_raises(contains="coordinate sequences must have equal length"):
        _ = Plot().with_line(two, one)
    with assert_raises(contains="x limits must satisfy lo < hi"):
        _ = Plot().with_line(one, one).with_xlim(2.0, 1.0)
    with assert_raises(contains="histogram bin count must be positive"):
        _ = Plot().with_histogram(two, bins=0)


def test_plot_figure_bridges_preserve_semantics_without_copies() raises:
    var x: List[Float64] = [0.0, 1.0, 2.0]
    var y: List[Float64] = [1.0, 2.0, 1.0]
    var plot = Plot().with_line(x, y, label="line").with_title("Bridge")
    plot.validate()

    ref borrowed = plot.figure()
    assert_equal(borrowed.line_count(), 1)
    assert_equal(borrowed.title(), "Bridge")

    var margins = Margins(24.0, 8.0, 8.0, 20.0)
    var explicit_plan = plot.build_render_plan(240.0, 160.0, margins)
    var explicit_reference = build_render_plan(plot.figure(), 240.0, 160.0, margins)
    assert_true(explicit_plan == explicit_reference)

    var default_plan = plot.build_render_plan(240.0, 160.0)
    var default_reference = build_render_plan(
        plot.figure(), 240.0, 160.0, Margins(12.0, 12.0, 12.0, 12.0)
    )
    assert_true(default_plan == default_reference)

    var expected_svg = plot.render_svg(240.0, 160.0, margins)
    var figure = plot^.into_figure()
    assert_equal(figure.render_svg(240.0, 160.0, margins), expected_svg)

    var restored = Plot(figure^)
    assert_equal(restored.render_svg(240.0, 160.0, margins), expected_svg)


def test_plot_save_svg_accepts_explicit_margins() raises:
    var x: List[Float64] = [0.0, 1.0]
    var y: List[Float64] = [0.0, 1.0]
    var plot = Plot().with_line(x, y)
    var margins = Margins(24.0, 8.0, 8.0, 20.0)
    var path = String(".pixi/plot-explicit-margins-test.svg")
    plot.save_svg(path, 240.0, 160.0, margins)
    with open(path, "r") as saved:
        assert_equal(saved.read(), plot.render_svg(240.0, 160.0, margins))


def test_plot_axis_controls_are_symmetric_and_restore_automatic_state() raises:
    var x: List[Float64] = [0.0, 1.0, 2.0]
    var y: List[Float64] = [1.0, 2.0, 3.0]
    var positions: List[Float64] = [0.0, 2.0]
    var x_labels: List[String] = ["left", "right"]
    var y_labels: List[String] = ["low", "high"]

    var plot = (
        Plot()
        .with_line(x, y)
        .with_xlim(-1.0, 3.0)
        .with_ylim(0.0, 4.0)
        .with_xticks(positions, x_labels)
        .with_yticks(positions, y_labels)
    )
    assert_true(plot.figure().x_limits())
    assert_true(plot.figure().y_limits())
    assert_true(plot.figure().has_explicit_x_ticks())
    assert_true(plot.figure().has_explicit_y_ticks())
    var explicit_svg = plot.render_svg()
    assert_true(">left</text>" in explicit_svg)
    assert_true(">high</text>" in explicit_svg)

    var automatic = (
        plot^.with_auto_xlim().with_auto_ylim().with_auto_xticks().with_auto_yticks()
    )
    assert_true(not automatic.figure().x_limits())
    assert_true(not automatic.figure().y_limits())
    assert_true(not automatic.figure().has_explicit_x_ticks())
    assert_true(not automatic.figure().has_explicit_y_ticks())

    automatic.xlim(-1.0, 3.0)
    automatic.ylim(0.0, 4.0)
    automatic.xticks(positions, x_labels)
    automatic.yticks(positions, y_labels)
    automatic.clear_xlim()
    automatic.clear_ylim()
    automatic.clear_xticks()
    automatic.clear_yticks()
    assert_true(not automatic.figure().x_limits())
    assert_true(not automatic.figure().y_limits())
    assert_true(not automatic.figure().has_explicit_x_ticks())
    assert_true(not automatic.figure().has_explicit_y_ticks())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
