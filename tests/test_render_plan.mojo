from sen import (
    AxisKind,
    CommandKind,
    DrawCommand,
    Figure,
    FigureConfig,
    LegendPosition,
    LineStyle,
    Margins,
    MarkerStyle,
    PlanPoint,
    RenderPlan,
    SeriesStyle,
    build_render_plan,
)
from std.collections import List
from std.testing import TestSuite, assert_equal, assert_raises, assert_true


def _figure() raises -> Figure:
    var x: List[Float64] = [0.0, 1.0, 2.0]
    var y: List[Float64] = [1.0, 3.0, 2.0]
    var figure = Figure()
    figure.line(x, y, label="data")
    return figure^


def _margins() raises -> Margins:
    return Margins(24.0, 8.0, 8.0, 20.0)


def _valid_command(kind: CommandKind) raises -> DrawCommand:
    var points = List[PlanPoint]()
    var text = String()
    var color = String()
    var palette_slot = -1
    var series_index = -1
    var line_width = 0.0
    var font_size = 0.0
    if (
        kind == CommandKind.X_LABEL
        or kind == CommandKind.Y_LABEL
        or kind == CommandKind.TITLE
        or kind == CommandKind.X_TITLE
        or kind == CommandKind.Y_TITLE
        or kind == CommandKind.LEGEND_TEXT
    ):
        font_size = 10.0
    if kind == CommandKind.SERIES:
        points.append(PlanPoint(1.0, 2.0))
        color = String("#123456")
        series_index = 0
        line_width = 1.5
    elif kind == CommandKind.AREA:
        points.append(PlanPoint(1.0, 3.0))
        points.append(PlanPoint(2.0, 1.0))
        points.append(PlanPoint(3.0, 3.0))
        color = String("#123456")
        series_index = 0
        line_width = 1.5
    elif kind == CommandKind.MARKER:
        palette_slot = 0
        series_index = 0
    elif kind == CommandKind.RECTANGLE:
        color = String("#123456")
        series_index = 0
    elif kind == CommandKind.LEGEND_LINE:
        color = String("#123456")
        line_width = 1.5
    elif kind == CommandKind.LEGEND_MARKER:
        palette_slot = 0
    elif kind == CommandKind.LEGEND_RECTANGLE:
        color = String("#123456")
    elif kind == CommandKind.LEGEND_AREA:
        color = String("#123456")
        line_width = 1.5
    return DrawCommand(
        kind,
        1.0,
        2.0,
        4.0,
        5.0,
        points^,
        text^,
        color^,
        palette_slot,
        series_index,
        line_width,
        LineStyle.SOLID,
        MarkerStyle.NONE,
        font_size=font_size,
    )


def test_public_lowering_is_valid_checked_and_deterministic() raises:
    var figure = _figure()
    var first = build_render_plan(figure, 160.0, 100.0, _margins())
    var second = build_render_plan(figure, 160.0, 100.0, _margins())

    first.validate()
    assert_true(first == second)
    assert_true(first.command_count() > 0)
    ref command = first.command(0)
    assert_true(command.kind == CommandKind.BACKGROUND)
    with assert_raises(contains="render command index is out of bounds"):
        _ = first.command(first.command_count())


def test_configured_plan_carries_physical_size_and_dpi_without_sentinels() raises:
    var figure = _figure()
    figure.set_config(FigureConfig(7.0, 5.0, dpi=300.0))

    var configured = build_render_plan(figure)
    assert_true(configured.figure_config)
    var config = configured.figure_config.value()
    assert_true(config.width() == 7.0)
    assert_true(config.height() == 5.0)
    assert_true(config.dpi() == 300.0)

    var legacy = build_render_plan(figure, 700.0, 500.0)
    assert_true(not legacy.figure_config)

    configured.figure_config = FigureConfig(8.0, 5.0, dpi=300.0)
    with assert_raises(contains="must match logical geometry"):
        configured.validate()


def _assert_extreme_finite_domain_lowers(maximum: Float64) raises:
    var x: List[Float64] = [-maximum, 0.0, maximum]
    var y: List[Float64] = [1.0, 2.0, 1.0]
    var tick_positions: List[Float64] = [-maximum, 0.0, maximum]
    var tick_labels: List[String] = [String("min"), String("0"), String("max")]
    var figure = Figure()
    figure.line(x, y)
    figure.set_x_limits(-maximum, maximum)
    figure.set_x_ticks(tick_positions, tick_labels)

    var plan = build_render_plan(figure, 160.0, 100.0, _margins())

    plan.validate()
    var found_series = False
    for index in range(plan.command_count()):
        ref command = plan.command(index)
        if command.kind == CommandKind.SERIES:
            found_series = True
            assert_equal(len(command.points), 3)
            assert_true(command.points[0].x == plan.plot_x)
            assert_true(command.points[1].x == plan.plot_x + plan.plot_width * 0.5)
            assert_true(command.points[2].x == plan.plot_x + plan.plot_width)
    assert_true(found_series)


def test_extreme_finite_domains_lower_to_valid_geometry() raises:
    _assert_extreme_finite_domain_lowers(Float64.MAX_FINITE)
    _assert_extreme_finite_domain_lowers(8.0e307)


def test_plan_points_and_commands_reject_invalid_public_construction() raises:
    with assert_raises(contains="render-plan points must be finite"):
        _ = PlanPoint(Float64("nan"), 0.0)

    var no_points = List[PlanPoint]()
    with assert_raises(contains="render command geometry must be finite"):
        _ = DrawCommand(
            CommandKind.AXIS,
            Float64("inf"),
            0.0,
            1.0,
            1.0,
            no_points^,
            String(),
            String(),
            -1,
            -1,
            1.0,
            LineStyle.SOLID,
            MarkerStyle.NONE,
        )

    var no_commands = List[DrawCommand]()
    with assert_raises(contains="render-plan must contain at least one command"):
        _ = RenderPlan(100.0, 80.0, 10.0, 10.0, 80.0, 60.0, no_commands^)


def test_every_command_kind_enforces_its_backend_invariants() raises:
    var kinds: List[CommandKind] = [
        CommandKind.BACKGROUND,
        CommandKind.FRAME,
        CommandKind.AXIS,
        CommandKind.TICK,
        CommandKind.X_LABEL,
        CommandKind.Y_LABEL,
        CommandKind.SERIES,
        CommandKind.TITLE,
        CommandKind.X_TITLE,
        CommandKind.Y_TITLE,
        CommandKind.MARKER,
        CommandKind.GRID,
        CommandKind.LEGEND_BACKGROUND,
        CommandKind.LEGEND_LINE,
        CommandKind.LEGEND_MARKER,
        CommandKind.LEGEND_TEXT,
        CommandKind.RECTANGLE,
        CommandKind.LEGEND_RECTANGLE,
        CommandKind.AREA,
        CommandKind.LEGEND_AREA,
    ]
    for kind in kinds:
        _valid_command(kind).validate()

    var rectangle_kinds: List[CommandKind] = [
        CommandKind.BACKGROUND,
        CommandKind.FRAME,
        CommandKind.LEGEND_BACKGROUND,
        CommandKind.RECTANGLE,
        CommandKind.LEGEND_RECTANGLE,
        CommandKind.LEGEND_AREA,
    ]
    for kind in rectangle_kinds:
        var invalid = _valid_command(kind)
        invalid.x2 = -1.0
        with assert_raises(contains="rectangle width and height must be nonnegative"):
            invalid.validate()
    var negative_height = _valid_command(CommandKind.BACKGROUND)
    negative_height.y2 = -1.0
    with assert_raises(contains="rectangle width and height must be nonnegative"):
        negative_height.validate()

    var series = _valid_command(CommandKind.SERIES)
    series.points = List[PlanPoint]()
    with assert_raises(contains="series commands require at least one point"):
        series.validate()
    series = _valid_command(CommandKind.SERIES)
    series.color = String()
    with assert_raises(contains="series commands require a color"):
        series.validate()
    series = _valid_command(CommandKind.SERIES)
    series.line_width = 0.0
    with assert_raises(contains="series commands require a positive line width"):
        series.validate()
    series = _valid_command(CommandKind.SERIES)
    series.series_index = -1
    with assert_raises(contains="data commands require a nonnegative series index"):
        series.validate()

    var area = _valid_command(CommandKind.AREA)
    area.points = List[PlanPoint]()
    area.points.append(PlanPoint(1.0, 1.0))
    area.points.append(PlanPoint(2.0, 2.0))
    with assert_raises(contains="area commands require at least three points"):
        area.validate()
    area = _valid_command(CommandKind.AREA)
    area.color = String()
    with assert_raises(contains="area commands require a color"):
        area.validate()
    area = _valid_command(CommandKind.AREA)
    area.line_width = 0.0
    with assert_raises(contains="area commands require a positive line width"):
        area.validate()
    area = _valid_command(CommandKind.AREA)
    area.series_index = -1
    with assert_raises(contains="data commands require a nonnegative series index"):
        area.validate()

    var marker = _valid_command(CommandKind.MARKER)
    marker.palette_slot = -1
    with assert_raises(contains="marker commands require a palette slot"):
        marker.validate()
    marker = _valid_command(CommandKind.MARKER)
    marker.series_index = -1
    with assert_raises(contains="data commands require a nonnegative series index"):
        marker.validate()

    var rectangle = _valid_command(CommandKind.RECTANGLE)
    rectangle.color = String()
    with assert_raises(contains="rectangle commands require a color"):
        rectangle.validate()
    rectangle = _valid_command(CommandKind.RECTANGLE)
    rectangle.series_index = -1
    with assert_raises(contains="data commands require a nonnegative series index"):
        rectangle.validate()

    var legend_line = _valid_command(CommandKind.LEGEND_LINE)
    legend_line.color = String()
    with assert_raises(contains="legend line commands require a color"):
        legend_line.validate()
    legend_line = _valid_command(CommandKind.LEGEND_LINE)
    legend_line.line_width = 0.0
    with assert_raises(contains="legend line commands require a positive line width"):
        legend_line.validate()

    var legend_marker = _valid_command(CommandKind.LEGEND_MARKER)
    legend_marker.palette_slot = -1
    with assert_raises(contains="legend marker commands require a palette slot"):
        legend_marker.validate()

    var legend_rectangle = _valid_command(CommandKind.LEGEND_RECTANGLE)
    legend_rectangle.color = String()
    with assert_raises(contains="legend rectangle commands require a color"):
        legend_rectangle.validate()

    var legend_area = _valid_command(CommandKind.LEGEND_AREA)
    legend_area.color = String()
    with assert_raises(contains="legend area commands require a color"):
        legend_area.validate()
    legend_area = _valid_command(CommandKind.LEGEND_AREA)
    legend_area.line_width = 0.0
    with assert_raises(contains="legend area commands require a positive line width"):
        legend_area.validate()


def test_generic_command_validation_covers_every_closed_range() raises:
    var invalid = _valid_command(CommandKind.AXIS)
    invalid.kind = CommandKind(_value=-1)
    with assert_raises(contains="kind is outside Sen's vocabulary"):
        invalid.validate()
    invalid = _valid_command(CommandKind.AXIS)
    invalid.kind = CommandKind(_value=20)
    with assert_raises(contains="kind is outside Sen's vocabulary"):
        invalid.validate()

    invalid = _valid_command(CommandKind.AXIS)
    invalid.line_width = Float64("nan")
    with assert_raises(contains="line width must be finite and nonnegative"):
        invalid.validate()
    invalid = _valid_command(CommandKind.AXIS)
    invalid.line_width = -1.0
    with assert_raises(contains="line width must be finite and nonnegative"):
        invalid.validate()

    invalid = _valid_command(CommandKind.AXIS)
    invalid.palette_slot = -2
    with assert_raises(contains="palette slot must be within -1..5"):
        invalid.validate()
    invalid = _valid_command(CommandKind.AXIS)
    invalid.palette_slot = 6
    with assert_raises(contains="palette slot must be within -1..5"):
        invalid.validate()
    invalid = _valid_command(CommandKind.AXIS)
    invalid.series_index = -2
    with assert_raises(contains="series index must be at least -1"):
        invalid.validate()

    invalid = _valid_command(CommandKind.AXIS)
    invalid.line_style = LineStyle(_value=-1)
    with assert_raises(contains="line style is outside Sen's vocabulary"):
        invalid.validate()
    invalid = _valid_command(CommandKind.AXIS)
    invalid.line_style = LineStyle(_value=4)
    with assert_raises(contains="line style is outside Sen's vocabulary"):
        invalid.validate()
    invalid = _valid_command(CommandKind.AXIS)
    invalid.marker_style = MarkerStyle(_value=-1)
    with assert_raises(contains="marker style is outside Sen's vocabulary"):
        invalid.validate()
    invalid = _valid_command(CommandKind.AXIS)
    invalid.marker_style = MarkerStyle(_value=8)
    with assert_raises(contains="marker style is outside Sen's vocabulary"):
        invalid.validate()

    invalid = _valid_command(CommandKind.AXIS)
    invalid.points.append(PlanPoint(1.0, 2.0))
    invalid.points[0].x = Float64("inf")
    with assert_raises(contains="render-plan points must be finite"):
        invalid.validate()


def test_explicit_validation_detects_post_construction_mutation() raises:
    var figure = _figure()
    var plan = build_render_plan(figure, 160.0, 100.0, _margins())
    plan.commands[0].x1 = Float64("nan")
    with assert_raises(contains="render command geometry must be finite"):
        plan.validate()

    var style_plan = build_render_plan(figure, 160.0, 100.0, _margins())
    style_plan.commands[0].line_style = LineStyle(_value=99)
    with assert_raises(contains="line style is outside Sen's vocabulary"):
        style_plan.validate()


def test_lowering_rejects_invalid_nominals_without_rescanning_points() raises:
    var invalid_axis = _figure()
    invalid_axis._x_scale = AxisKind(_value=2)
    with assert_raises(contains="axis kind is outside Sen's vocabulary"):
        _ = build_render_plan(invalid_axis, 160.0, 100.0, _margins())

    var invalid_legend = _figure()
    invalid_legend._legend_position = LegendPosition(_value=-1)
    with assert_raises(contains="legend position is outside Sen's vocabulary"):
        _ = build_render_plan(invalid_legend, 160.0, 100.0, _margins())

    var invalid_style = _figure()
    invalid_style._line_styles[0] = SeriesStyle().with_marker_style(
        MarkerStyle(_value=8)
    )
    with assert_raises(contains="marker style is outside Sen's vocabulary"):
        _ = build_render_plan(invalid_style, 160.0, 100.0, _margins())


def test_explicit_y_ticks_filter_labels_and_align_horizontal_grid() raises:
    var x: List[Float64] = [0.0, 1.0]
    var y: List[Float64] = [0.0, 10.0]
    var ticks: List[Float64] = [-1.0, 2.0, 8.0, 11.0]
    var labels: List[String] = ["below", "two", "eight", "above"]
    var figure = Figure()
    figure.line(x, y)
    figure.set_y_limits(0.0, 10.0)
    figure.set_y_ticks(ticks, labels)
    figure.set_grid(True)

    var plan = build_render_plan(figure, 160.0, 100.0, _margins())
    var y_label_count = 0
    var horizontal_grid_count = 0
    for command_index in range(plan.command_count()):
        ref command = plan.command(command_index)
        if command.kind == CommandKind.Y_LABEL:
            assert_true(command.text == "two" or command.text == "eight")
            y_label_count += 1
            var aligned = False
            for grid_index in range(plan.command_count()):
                ref grid = plan.command(grid_index)
                if (
                    grid.kind == CommandKind.GRID
                    and grid.y1 == grid.y2
                    and abs(grid.y1 - (command.y1 - command.font_size * 0.32)) < 1.0e-12
                ):
                    aligned = True
            assert_true(aligned)
        if command.kind == CommandKind.GRID and command.y1 == command.y2:
            horizontal_grid_count += 1
    assert_equal(y_label_count, 2)
    assert_equal(horizontal_grid_count, 2)


def test_log_y_axis_rejects_nonpositive_explicit_ticks() raises:
    var x: List[Float64] = [1.0, 10.0]
    var y: List[Float64] = [1.0, 10.0]
    var ticks: List[Float64] = [0.0, 1.0]
    var labels: List[String] = ["zero", "one"]
    var figure = Figure()
    figure.line(x, y)
    figure.set_y_ticks(ticks, labels)
    figure.set_y_scale(AxisKind.LOG10)

    with assert_raises(contains="log-scale y tick positions must be positive; tick 0"):
        _ = build_render_plan(figure, 160.0, 100.0, _margins())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
