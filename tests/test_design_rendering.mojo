from sen import Figure, FigureConfig, LineCap, LineJoin, SeriesStyle, Theme, render_svg
from std.collections import List
from std.testing import TestSuite, assert_equal, assert_true


def _line_figure() raises -> Figure:
    var xs: List[Float64] = [0.0, 1.0, 2.0]
    var ys: List[Float64] = [0.0, 1.0, 0.5]
    var figure = Figure()
    figure.line(xs, ys)
    return figure^


def test_svg_geometry_is_byte_identical_across_export_dpi() raises:
    var low_dpi = _line_figure()
    low_dpi.set_config(FigureConfig(6.4, 4.8, dpi=72.0))
    var high_dpi = _line_figure()
    high_dpi.set_config(FigureConfig(6.4, 4.8, dpi=300.0))

    var low_svg = render_svg(low_dpi)
    var high_svg = render_svg(high_dpi)

    assert_equal(low_svg, high_svg)
    assert_true(
        low_svg.startswith(
            '<svg xmlns="http://www.w3.org/2000/svg" role="img" width="6.4in" '
            'height="4.8in" viewBox="0 0 640 480">'
        )
    )


def test_physical_size_changes_root_extent_and_logical_viewbox_together() raises:
    var figure = _line_figure()
    figure.set_config(FigureConfig(8.0, 5.0, dpi=144.0))

    var svg = render_svg(figure)
    assert_true(
        svg.startswith(
            '<svg xmlns="http://www.w3.org/2000/svg" role="img" width="8in" '
            'height="5in" viewBox="0 0 800 500">'
        )
    )


def test_dark_theme_applies_to_background_text_grid_frame_and_legend() raises:
    var xs: List[Float64] = [0.0, 1.0, 2.0]
    var ys: List[Float64] = [0.0, 1.0, 0.5]
    var figure = Figure()
    figure.line(xs, ys, label="系列")
    figure.set_grid(True)
    figure.set_theme(Theme.dark())

    var svg = render_svg(figure)
    assert_true('class="sen-background"' in svg)
    assert_true('fill="#111827"' in svg)
    assert_true('fill="#e5e7eb"' in svg)
    assert_true('stroke="#374151"' in svg)
    assert_true('stroke="#6b7280"' in svg)
    assert_true('class="sen-legend"' in svg)
    assert_true('fill="#1f2937"' in svg)


def test_full_cjk_labels_are_preserved_and_dense_x_labels_are_selected() raises:
    var xs: List[Float64] = [0.0, 1.0, 2.0, 3.0, 4.0, 5.0]
    var ys: List[Float64] = [0.0, 1.0, 2.0, 1.0, 2.0, 3.0]
    var labels: List[String] = [
        "日本語ラベル",
        "简体中文标签",
        "繁體中文標籤",
        "한국어레이블",
        "かなカナ漢字",
        "測定完了✅",
    ]
    var figure = Figure()
    figure.line(xs, ys)
    figure.set_title("日本語・简体中文・繁體中文・한국어")
    figure.set_x_label("時刻 / 时间 / 시간")
    figure.set_y_label("測定値")
    figure.set_x_ticks(xs, labels)
    figure.set_config(FigureConfig(3.2, 2.4))

    var svg = render_svg(figure)
    assert_true("<title>日本語・简体中文・繁體中文・한국어</title>" in svg)
    assert_true(">日本語・简体中文・</text>" in svg)
    assert_true(">繁體中文・한국어</text>" in svg)
    assert_true(">時刻 / 时间 / 시간</text>" in svg)
    assert_true(">測定値</text>" in svg)
    assert_true(">日本語ラベル</text>" in svg)
    assert_true(">測定完了✅</text>" in svg)
    assert_true(">简体中文标签</text>" not in svg)
    assert_true('"Noto Sans CJK JP"' not in svg)
    assert_true("&quot;Noto Sans CJK JP&quot;" in svg)


def test_series_style_points_caps_joins_and_opacity_reach_svg() raises:
    var xs: List[Float64] = [0.0, 1.0]
    var ys: List[Float64] = [0.0, 1.0]
    var style = (
        SeriesStyle()
        .with_line_width(3.0)
        .with_marker_size(10.0)
        .with_opacity(0.6)
        .with_line_cap(LineCap.SQUARE)
        .with_line_join(LineJoin.BEVEL)
    )
    var figure = Figure()
    figure.line(xs, ys, style=style)

    var svg = render_svg(figure)
    assert_true('stroke-width="4.167"' in svg)
    assert_true('opacity="0.6"' in svg)
    assert_true('stroke-linecap="square"' in svg)
    assert_true('stroke-linejoin="bevel"' in svg)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
