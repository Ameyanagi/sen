from kumihan import FontFace
from sen import Plot, Typography, Theme, CommandKind, encode_svg
from sen_kumihan import KumihanTextMetrics
from std.pathlib import Path
from std.testing import TestSuite, assert_almost_equal, assert_true, assert_raises
from std.os import makedirs


def _metrics(
    path: StringSlice = "tests/fixtures/metrics.ttf",
) raises -> KumihanTextMetrics:
    var data = Path(path).read_bytes()
    return KumihanTextMetrics(FontFace.from_bytes(data^), "Sen Metrics Fixture")


def test_font_advances_come_from_published_kumihan() raises:
    var metrics = _metrics()
    assert_almost_equal(metrics.width("AW 日本", 10.0), 39.0, atol=1e-12)
    assert_almost_equal(metrics.height(10.0), 11.0, atol=1e-12)
    assert_almost_equal(metrics.ascent(1e308) / 1e308, 0.8, atol=1e-12)
    assert_almost_equal(metrics.descent(1e308) / 1e308, 0.2, atol=1e-12)
    with assert_raises(contains="missing glyphs"):
        _ = metrics.width("unsupported", 10.0)
    with assert_raises(contains="font family must match"):
        metrics.validate_family("Other")


def _render_fixture(font_path: StringSlice, output_name: StringSlice) raises:
    var x: List[Float64] = [0.0, 1.0, 2.0, 3.0]
    var y: List[Float64] = [1.0, 2.0, 1.0, 3.0]
    var plot = Plot().with_line(x, y, label="  AW  日本語  ").with_size(6.4, 4.8)
    plot.title("AW 日本語 AW 日本語 AW 日本語 AW 日本語 AW 日本語 AW 日本語")
    plot.xlabel("M AW 日本")
    plot.ylabel("日本語 M")
    plot.description(
        "Horizontal axis AW 日本; vertical axis 日本語 M. One line series AW 日本語."
    )
    plot.theme(Theme().with_typography(Typography().with_family("Sen Metrics Fixture")))
    var positions: List[Float64] = [0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0]
    var labels: List[String] = ["AW00", "AW05", "AW10", "AW15", "AW20", "AW25", "AW30"]
    plot.xticks(positions, labels)
    var metrics = _metrics(font_path)
    var plan = plot.build_render_plan(metrics)
    var previous_right = -1.0
    var legend_right = 0.0
    var title_count = 0
    var measurement_lines = String()
    for command in plan.commands:
        if command.text.byte_length() > 0:
            measurement_lines += (
                command.text
                + "\t"
                + String(metrics.width(command.text, command.font_size))
                + "\n"
            )
        if command.kind == CommandKind.TITLE:
            title_count += 1
            assert_true(
                metrics.width(command.text, command.font_size)
                <= plan.plot_width + 0.001
            )
        elif command.kind == CommandKind.X_LABEL:
            var half_width = metrics.width(command.text, command.font_size) / 2.0
            assert_true(command.x1 - half_width >= previous_right)
            previous_right = command.x1 + half_width
        elif command.kind == CommandKind.LEGEND_BACKGROUND:
            legend_right = command.x1 + command.x2
        elif command.kind == CommandKind.LEGEND_TEXT:
            assert_true(
                command.x1 + metrics.width(command.text, command.font_size)
                < legend_right
            )
    assert_true(title_count == 2)
    var svg = encode_svg(plan)
    assert_true("font-kerning:none;font-variant-ligatures:none" in svg)
    makedirs("output", exist_ok=True)
    Path("output/" + output_name + ".svg").write_text(svg)
    Path("output/" + output_name + ".tsv").write_text(measurement_lines)


def test_real_font_layout_writes_visual_golden() raises:
    _render_fixture("tests/fixtures/metrics.ttf", "metrics-layout")


def test_deep_font_extents_write_visual_golden() raises:
    _render_fixture("tests/fixtures/metrics-deep.ttf", "metrics-deep")


def test_axis_titles_reject_missing_glyphs() raises:
    var x: List[Float64] = [0.0, 1.0]
    var y: List[Float64] = [1.0, 2.0]
    var plot = (
        Plot()
        .with_line(x, y)
        .with_theme(
            Theme().with_typography(Typography().with_family("Sen Metrics Fixture"))
        )
    )
    var metrics = _metrics()
    plot.xlabel("unsupported")
    with assert_raises(contains="missing glyphs"):
        _ = plot.build_render_plan(metrics)
    plot.xlabel("AW")
    plot.ylabel("unsupported")
    with assert_raises(contains="missing glyphs"):
        _ = plot.build_render_plan(metrics)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
