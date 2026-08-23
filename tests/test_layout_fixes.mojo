from sen import (
    AxisKind,
    CommandKind,
    DrawCommand,
    Figure,
    LegendPosition,
    LineCap,
    LineJoin,
    Margins,
    MarkerStyle,
    PlanPoint,
    RenderPlan,
    SeriesStyle,
    Text,
    build_render_plan,
)
from sen.lowering import _legend_overlap_scores
from sen.text_metrics import text_width
from std.collections import List
from std.testing import TestSuite, assert_equal, assert_raises, assert_true


def _line_figure() raises -> Figure:
    var xs: List[Float64] = [0.0, 100.0]
    var ys: List[Float64] = [0.0, 10.0]
    var figure = Figure()
    figure.line(xs, ys)
    figure.set_x_limits(0.0, 100.0)
    figure.set_y_limits(0.0, 10.0)
    return figure^


def _count(plan: RenderPlan, kind: CommandKind) raises -> Int:
    var count = 0
    for index in range(plan.command_count()):
        if plan.command(index).kind == kind:
            count += 1
    return count


def test_irregular_ticks_keep_every_mark_and_greedily_drop_only_labels() raises:
    var positions: List[Float64] = [0.0, 1.0, 2.0, 70.0, 100.0]
    var labels: List[String] = ["zero", "one", "two", "seventy", "hundred"]
    var figure = _line_figure()
    figure.set_x_ticks(positions, labels)
    figure.set_grid(True)

    var plan = build_render_plan(figure, 260.0, 150.0, Margins(18.0, 18.0, 12.0, 18.0))

    var x_tick_count = 0
    var x_grid_count = 0
    for index in range(plan.command_count()):
        ref command = plan.command(index)
        if command.kind == CommandKind.TICK and command.x1 == command.x2:
            x_tick_count += 1
        elif command.kind == CommandKind.GRID and command.x1 == command.x2:
            x_grid_count += 1
    assert_equal(x_tick_count, 5)
    assert_equal(x_grid_count, 5)
    assert_true(_count(plan, CommandKind.X_LABEL) < 5)
    var previous_right = -1.0
    for index in range(plan.command_count()):
        ref command = plan.command(index)
        if command.kind != CommandKind.X_LABEL:
            continue
        var left = command.x1 - text_width(command.text, command.font_size) / 2.0
        assert_true(left >= previous_right)
        previous_right = command.x1 + text_width(command.text, command.font_size) / 2.0


def test_explicit_ticks_reject_duplicates_and_unsorted_input_atomically() raises:
    var valid_positions: List[Float64] = [0.0, 50.0, 100.0]
    var valid_labels: List[String] = ["low", "middle", "high"]
    var duplicate_positions: List[Float64] = [0.0, 50.0, 50.0]
    var duplicate_labels: List[String] = ["low", "middle", "duplicate"]
    var unsorted_positions: List[Float64] = [0.0, 75.0, 25.0]
    var unsorted_labels: List[String] = ["low", "high", "middle"]
    var figure = _line_figure()
    figure.set_x_ticks(valid_positions, valid_labels)

    with assert_raises(
        contains="x tick positions must be strictly increasing; index 2"
    ):
        figure.set_x_ticks(duplicate_positions, duplicate_labels)
    assert_equal(figure.x_tick_label(2), "high")

    with assert_raises(
        contains="x tick positions must be strictly increasing; index 2"
    ):
        figure.set_x_ticks(unsorted_positions, unsorted_labels)
    assert_equal(figure.x_tick_label(1), "middle")

    var y_positions: List[Float64] = [0.0, 5.0, 5.0]
    var y_labels: List[String] = ["low", "middle", "duplicate"]
    with assert_raises(
        contains="y tick positions must be strictly increasing; index 2"
    ):
        figure.set_y_ticks(y_positions, y_labels)


def test_long_role_text_stays_inside_asymmetric_layout() raises:
    var figure = _line_figure()
    figure.set_title("非常に長い科学プロットのタイトルは読みやすく二行以内に収まります")
    figure.set_x_label("非常に長い横軸ラベルがキャンバスの外へはみ出してはいけません")
    figure.set_y_label("非常に長い縦軸ラベルがキャンバスの外へはみ出してはいけません")

    var plan = build_render_plan(figure, 360.0, 240.0, Margins(105.0, 18.0, 10.0, 16.0))
    var title_count = 0
    for index in range(plan.command_count()):
        ref command = plan.command(index)
        if command.kind == CommandKind.TITLE:
            title_count += 1
            assert_true(command.font_size >= 11.0 * 100.0 / 72.0)
            assert_true(text_width(command.text, command.font_size) <= plan.plot_width)
            assert_true(
                command.x1 - text_width(command.text, command.font_size) / 2.0 >= 0.0
            )
            assert_true(
                command.x1 + text_width(command.text, command.font_size) / 2.0
                <= plan.width
            )
        elif command.kind == CommandKind.X_TITLE:
            assert_true(text_width(command.text, command.font_size) <= plan.plot_width)
            assert_true(command.text.endswith("…"))
        elif command.kind == CommandKind.Y_TITLE:
            assert_true(text_width(command.text, command.font_size) <= plan.plot_height)
            assert_true(command.text.endswith("…"))
    assert_true(title_count > 0 and title_count <= 2)


def test_typst_roles_reserve_a_tall_bounded_line_box() raises:
    var figure = _line_figure()
    figure.set_title(Text.typst_math("$ integral_0^1 x dif x $"))
    figure.set_x_label(Text.typst_math("$ integral_0^1 x dif x $"))
    figure.set_y_label(Text.typst_math("$ integral_0^1 x dif x $"))

    var plan = build_render_plan(figure, 360.0, 240.0, Margins(12.0, 12.0, 12.0, 12.0))
    var title_font = 0.0
    var title_y = 0.0
    var x_font = 0.0
    var x_y = 0.0
    var y_font = 0.0
    var y_x = 0.0
    for index in range(plan.command_count()):
        ref command = plan.command(index)
        if command.kind == CommandKind.TITLE:
            title_font = command.font_size
            title_y = command.y1
        elif command.kind == CommandKind.X_TITLE:
            x_font = command.font_size
            x_y = command.y1
        elif command.kind == CommandKind.Y_TITLE:
            y_font = command.font_size
            y_x = command.x1
    # The SVG encoder's 2.4-em box extends 0.9 em below its command anchor.
    assert_true(title_y + title_font * 0.9 < plan.plot_y)
    assert_true(x_y + x_font * 0.9 <= plan.height - 8.0)
    # After the -90-degree rotation the same lower extension points left.
    assert_true(y_x - y_font * 0.9 >= 8.0 - 1.0e-12)


def test_large_legend_glyphs_fit_and_best_scores_area_interiors() raises:
    var marker_x: List[Float64] = [20.0]
    var marker_y: List[Float64] = [2.0]
    var marker_style = (
        SeriesStyle().with_marker_style(MarkerStyle.CIRCLE).with_marker_size(38.0)
    )
    var marker_figure = _line_figure()
    marker_figure.scatter(marker_x, marker_y, label="large marker", style=marker_style)
    marker_figure.set_legend(LegendPosition.UPPER_LEFT)
    var marker_plan = build_render_plan(marker_figure, 420.0, 260.0)
    var background_x = 0.0
    var background_y = 0.0
    var background_width = 0.0
    var background_height = 0.0
    var glyph_x = 0.0
    var glyph_y = 0.0
    var glyph_radius = 0.0
    for index in range(marker_plan.command_count()):
        ref command = marker_plan.command(index)
        if command.kind == CommandKind.LEGEND_BACKGROUND:
            background_x = command.x1
            background_y = command.y1
            background_width = command.x2
            background_height = command.y2
        elif command.kind == CommandKind.LEGEND_MARKER:
            glyph_x = command.x1
            glyph_y = command.y1
            glyph_radius = command.marker_size / 2.0
    assert_true(glyph_x - glyph_radius >= background_x)
    assert_true(glyph_x + glyph_radius <= background_x + background_width)
    assert_true(glyph_y - glyph_radius >= background_y)
    assert_true(glyph_y + glyph_radius <= background_y + background_height)

    var area_x: List[Float64] = [50.0, 100.0]
    var area_y: List[Float64] = [10.0, 10.0]
    var area_figure = Figure()
    area_figure.area(area_x, area_y, baseline=5.0, label="filled region")
    area_figure.set_x_limits(0.0, 100.0)
    area_figure.set_y_limits(0.0, 10.0)
    area_figure.set_legend(LegendPosition.BEST)
    var area_plan = build_render_plan(area_figure, 420.0, 260.0)
    var legend_x = 0.0
    var legend_width = 0.0
    for index in range(area_plan.command_count()):
        ref command = area_plan.command(index)
        if command.kind == CommandKind.LEGEND_BACKGROUND:
            legend_x = command.x1
            legend_width = command.x2
    var upper_right_x = area_plan.plot_x + area_plan.plot_width - 8.0 - legend_width
    assert_true(legend_x < upper_right_x)


def _assert_data_geometry_fits(plan: RenderPlan) raises:
    for index in range(plan.command_count()):
        ref command = plan.command(index)
        if command.kind == CommandKind.MARKER:
            var radius = command.marker_size / 2.0
            assert_true(command.x1 - radius >= plan.plot_x - 1.0e-10)
            assert_true(command.x1 + radius <= plan.plot_x + plan.plot_width + 1.0e-10)
            assert_true(command.y1 - radius >= plan.plot_y - 1.0e-10)
            assert_true(command.y1 + radius <= plan.plot_y + plan.plot_height + 1.0e-10)
        elif command.kind == CommandKind.SERIES:
            var radius = command.line_width / 2.0
            for point in command.points:
                assert_true(point.x - radius >= plan.plot_x - 1.0e-10)
                assert_true(point.x + radius <= plan.plot_x + plan.plot_width + 1.0e-10)
                assert_true(point.y - radius >= plan.plot_y - 1.0e-10)
                assert_true(
                    point.y + radius <= plan.plot_y + plan.plot_height + 1.0e-10
                )


def test_automatic_linear_domain_contains_huge_endpoint_geometry() raises:
    var xs: List[Float64] = [0.0, 10.0]
    var ys: List[Float64] = [0.0, 10.0]
    var marker_style = SeriesStyle().with_marker_size(52.0)
    var stroke_style = SeriesStyle().with_line_width(44.0)
    var figure = Figure()
    figure.scatter(xs, ys, style=marker_style)
    figure.line(xs, ys, style=stroke_style)

    var plan = build_render_plan(figure, 360.0, 240.0)
    _assert_data_geometry_fits(plan)


def test_automatic_log_domain_contains_huge_endpoint_markers() raises:
    var xs: List[Float64] = [1.0, 1000.0]
    var ys: List[Float64] = [0.1, 100.0]
    var style = SeriesStyle().with_marker_size(42.0)
    var figure = Figure()
    figure.scatter(xs, ys, style=style)
    figure.set_x_scale(AxisKind.LOG10)
    figure.set_y_scale(AxisKind.LOG10)

    var plan = build_render_plan(figure, 360.0, 240.0)
    _assert_data_geometry_fits(plan)


def test_impossible_automatic_geometry_has_actionable_error() raises:
    var xs: List[Float64] = [0.0, 1.0]
    var ys: List[Float64] = [0.0, 1.0]
    var style = SeriesStyle().with_marker_size(1000.0)
    var figure = Figure()
    figure.scatter(xs, ys, style=style)

    with assert_raises(
        contains=(
            "series geometry cannot fit within the x plot span; reduce marker size "
            "or line width, increase figure width, or set explicit limits to clip "
            "intentionally"
        )
    ):
        _ = build_render_plan(figure, 180.0, 140.0)


def test_explicit_limits_keep_exact_endpoint_clipping() raises:
    var xs: List[Float64] = [0.0, 10.0]
    var ys: List[Float64] = [0.0, 10.0]
    var style = (
        SeriesStyle().with_marker_style(MarkerStyle.CROSS).with_marker_size(52.0)
    )
    var figure = Figure()
    figure.scatter(xs, ys, style=style)
    figure.set_x_limits(0.0, 10.0)
    figure.set_y_limits(0.0, 10.0)

    var plan = build_render_plan(figure, 360.0, 240.0)
    var endpoint_count = 0
    for index in range(plan.command_count()):
        ref command = plan.command(index)
        if command.kind != CommandKind.MARKER:
            continue
        endpoint_count += 1
        assert_true(
            command.x1 == plan.plot_x or command.x1 == plan.plot_x + plan.plot_width
        )
    assert_equal(endpoint_count, 2)


def _assert_line_extent_fits(plan: RenderPlan, half_extent: Float64) raises:
    for index in range(plan.command_count()):
        ref command = plan.command(index)
        if command.kind != CommandKind.SERIES:
            continue
        for point in command.points:
            assert_true(point.x - half_extent >= plan.plot_x - 1.0e-9)
            assert_true(point.x + half_extent <= plan.plot_x + plan.plot_width + 1.0e-9)
            assert_true(point.y - half_extent >= plan.plot_y - 1.0e-9)
            assert_true(
                point.y + half_extent <= plan.plot_y + plan.plot_height + 1.0e-9
            )


def test_square_cap_diagonal_line_extents_fit_automatic_axes() raises:
    var xs: List[Float64] = [0.0, 10.0]
    var ys: List[Float64] = [0.0, 10.0]
    var style = SeriesStyle().with_line_width(32.0).with_line_cap(LineCap.SQUARE)
    var figure = Figure()
    figure.line(xs, ys, style=style)

    var plan = build_render_plan(figure, 380.0, 260.0)
    var half_stroke = 32.0 * 100.0 / 72.0 / 2.0
    _assert_line_extent_fits(plan, half_stroke * 1.4142135623730951)


def test_acute_miter_join_extents_fit_automatic_axes() raises:
    var xs: List[Float64] = [0.0, 5.0, 5.2]
    var ys: List[Float64] = [0.0, 10.0, 0.0]
    var style = SeriesStyle().with_line_width(22.0).with_line_join(LineJoin.MITER)
    var figure = Figure()
    figure.line(xs, ys, style=style)

    var plan = build_render_plan(figure, 420.0, 300.0)
    var half_stroke = 22.0 * 100.0 / 72.0 / 2.0
    _assert_line_extent_fits(plan, half_stroke * 4.0)


def test_diagonal_cross_marker_stroke_extents_fit_automatic_axes() raises:
    var xs: List[Float64] = [0.0, 10.0]
    var ys: List[Float64] = [0.0, 10.0]
    var style = (
        SeriesStyle().with_marker_style(MarkerStyle.CROSS).with_marker_size(54.0)
    )
    var figure = Figure()
    figure.scatter(xs, ys, style=style)

    var plan = build_render_plan(figure, 380.0, 260.0)
    var diameter = 54.0 * 100.0 / 72.0
    var half_extent = diameter / 2.0 + max(1.0, diameter * 0.24) / 2.0
    for index in range(plan.command_count()):
        ref command = plan.command(index)
        if command.kind != CommandKind.MARKER:
            continue
        assert_true(command.x1 - half_extent >= plan.plot_x - 1.0e-9)
        assert_true(command.x1 + half_extent <= plan.plot_x + plan.plot_width + 1.0e-9)
        assert_true(command.y1 - half_extent >= plan.plot_y - 1.0e-9)
        assert_true(command.y1 + half_extent <= plan.plot_y + plan.plot_height + 1.0e-9)


def _oracle_rectangles_overlap(
    ax: Float64,
    ay: Float64,
    aw: Float64,
    ah: Float64,
    bx: Float64,
    by: Float64,
    bw: Float64,
    bh: Float64,
) -> Bool:
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by


def _oracle_point_in_polygon(points: List[PlanPoint], x: Float64, y: Float64) -> Bool:
    var inside = False
    var previous_index = len(points) - 1
    for index in range(len(points)):
        ref point = points[index]
        ref previous = points[previous_index]
        if (point.y > y) != (previous.y > y):
            var crossing_x = (previous.x - point.x) * (y - point.y) / (
                previous.y - point.y
            ) + point.x
            if x < crossing_x:
                inside = not inside
        previous_index = index
    return inside


def _oracle_legend_score(
    plan: RenderPlan, x: Float64, y: Float64, width: Float64, height: Float64
) raises -> Int:
    """Retain the former one-candidate scoring semantics as a test oracle."""
    var score = 0
    for command_index in range(plan.command_count()):
        ref command = plan.command(command_index)
        if command.kind == CommandKind.MARKER:
            var radius = command.marker_size / 2.0
            if _oracle_rectangles_overlap(
                command.x1 - radius,
                command.y1 - radius,
                2.0 * radius,
                2.0 * radius,
                x,
                y,
                width,
                height,
            ):
                score += 4
        elif command.kind == CommandKind.RECTANGLE:
            if _oracle_rectangles_overlap(
                command.x1,
                command.y1,
                command.x2,
                command.y2,
                x,
                y,
                width,
                height,
            ):
                score += 5
        elif command.kind == CommandKind.SERIES or command.kind == CommandKind.AREA:
            if command.kind == CommandKind.AREA:
                if (
                    _oracle_point_in_polygon(command.points, x, y)
                    or _oracle_point_in_polygon(command.points, x + width, y)
                    or _oracle_point_in_polygon(command.points, x, y + height)
                    or _oracle_point_in_polygon(command.points, x + width, y + height)
                    or _oracle_point_in_polygon(
                        command.points, x + width / 2.0, y + height / 2.0
                    )
                ):
                    score += 8
            for point in command.points:
                if (
                    point.x >= x
                    and point.x <= x + width
                    and point.y >= y
                    and point.y <= y + height
                ):
                    score += 3
            for point_index in range(1, len(command.points)):
                ref first = command.points[point_index - 1]
                ref second = command.points[point_index]
                var stroke_radius = command.line_width / 2.0
                var segment_x = min(first.x, second.x) - stroke_radius
                var segment_y = min(first.y, second.y) - stroke_radius
                var segment_width = abs(second.x - first.x) + 2.0 * stroke_radius
                var segment_height = abs(second.y - first.y) + 2.0 * stroke_radius
                if _oracle_rectangles_overlap(
                    segment_x,
                    segment_y,
                    max(segment_width, 0.001),
                    max(segment_height, 0.001),
                    x,
                    y,
                    width,
                    height,
                ):
                    score += 1
    return score


def test_best_legend_single_pass_matches_four_scan_oracle_for_all_geometry() raises:
    var line_x: List[Float64] = [0.0, 10.0]
    var line_y: List[Float64] = [8.0, 8.0]
    var area_x: List[Float64] = [5.0, 10.0]
    var area_y: List[Float64] = [10.0, 10.0]
    var marker_x: List[Float64] = [1.0]
    var marker_y: List[Float64] = [1.0]
    var bar_x: List[Float64] = [8.0]
    var bar_height: List[Float64] = [3.0]
    var figure = Figure()
    figure.line(line_x, line_y, label="line")
    figure.area(area_x, area_y, baseline=6.0, label="area")
    figure.scatter(marker_x, marker_y, label="marker")
    figure.bar(bar_x, bar_height, width=1.0, baseline=0.0, label="bar")
    figure.set_x_limits(0.0, 10.0)
    figure.set_y_limits(0.0, 10.0)
    figure.set_legend(LegendPosition.BEST)

    var plan = build_render_plan(figure, 640.0, 480.0)
    var legend_x = 0.0
    var legend_y = 0.0
    var legend_width = 0.0
    var legend_height = 0.0
    var commands = List[DrawCommand](capacity=plan.command_count())
    for index in range(plan.command_count()):
        ref command = plan.command(index)
        commands.append(command.copy())
        if command.kind == CommandKind.LEGEND_BACKGROUND:
            legend_x = command.x1
            legend_y = command.y1
            legend_width = command.x2
            legend_height = command.y2
    var left_x = plan.plot_x + 8.0
    var right_x = plan.plot_x + plan.plot_width - 8.0 - legend_width
    var top_y = plan.plot_y + 8.0
    var bottom_y = plan.plot_y + plan.plot_height - 8.0 - legend_height
    var upper_right = _oracle_legend_score(
        plan, right_x, top_y, legend_width, legend_height
    )
    var upper_left = _oracle_legend_score(
        plan, left_x, top_y, legend_width, legend_height
    )
    var lower_right = _oracle_legend_score(
        plan, right_x, bottom_y, legend_width, legend_height
    )
    var lower_left = _oracle_legend_score(
        plan, left_x, bottom_y, legend_width, legend_height
    )
    var multi = _legend_overlap_scores(
        commands,
        left_x,
        right_x,
        top_y,
        bottom_y,
        legend_width,
        legend_height,
    )
    assert_equal(multi.upper_right, upper_right)
    assert_equal(multi.upper_left, upper_left)
    assert_equal(multi.lower_right, lower_right)
    assert_equal(multi.lower_left, lower_left)

    var expected_x = right_x
    var expected_y = top_y
    var best_score = upper_right
    if upper_left < best_score:
        best_score = upper_left
        expected_x = left_x
    if lower_right < best_score:
        best_score = lower_right
        expected_x = right_x
        expected_y = bottom_y
    if lower_left < best_score:
        expected_x = left_x
        expected_y = bottom_y
    assert_true(legend_x == expected_x)
    assert_true(legend_y == expected_y)


def test_best_legend_equal_scores_keep_upper_right_priority() raises:
    var xs: List[Float64] = [4.5, 5.5]
    var ys: List[Float64] = [5.0, 5.0]
    var figure = Figure()
    figure.line(xs, ys, label="center")
    figure.set_x_limits(0.0, 10.0)
    figure.set_y_limits(0.0, 10.0)
    figure.set_legend(LegendPosition.BEST)

    var plan = build_render_plan(figure, 640.0, 480.0)
    for index in range(plan.command_count()):
        ref command = plan.command(index)
        if command.kind != CommandKind.LEGEND_BACKGROUND:
            continue
        assert_true(command.x1 == plan.plot_x + plan.plot_width - 8.0 - command.x2)
        assert_true(command.y1 == plan.plot_y + 8.0)


def test_latin_title_wrap_prefers_word_boundaries_and_preserves_accessibility() raises:
    var original = String(
        "A careful analysis of longitudinal measurements across populations"
    )
    var figure = _line_figure()
    figure.set_title(original.copy())

    var plan = build_render_plan(figure, 300.0, 200.0)
    var title_lines = List[String]()
    for index in range(plan.command_count()):
        ref command = plan.command(index)
        if command.kind == CommandKind.TITLE:
            title_lines.append(command.text.copy())
    assert_equal(len(title_lines), 2)
    assert_equal(title_lines[0] + " " + title_lines[1], original)
    assert_equal(plan.accessible_title, original)


def test_very_long_unbroken_title_fits_in_bounded_work() raises:
    var original = String("測")
    for _ in range(12):
        var copy = original.copy()
        original += copy
    var figure = _line_figure()
    figure.set_title(original.copy())

    var plan = build_render_plan(figure, 320.0, 200.0)
    var title_count = 0
    var found_ellipsis = False
    for index in range(plan.command_count()):
        ref command = plan.command(index)
        if command.kind == CommandKind.TITLE:
            title_count += 1
            found_ellipsis = found_ellipsis or command.text.endswith("…")
            assert_true(text_width(command.text, command.font_size) <= plan.plot_width)
    assert_equal(title_count, 2)
    assert_true(found_ellipsis)
    assert_equal(plan.accessible_title, original)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
