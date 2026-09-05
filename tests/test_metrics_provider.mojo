from sen import (
    Plot,
    TextMetrics,
    FallbackTextMetrics,
    Theme,
    Typography,
    CommandKind,
    build_render_plan,
    encode_svg,
)
from std.testing import TestSuite, assert_true, assert_equal, assert_raises
from sen.lowering import _plain_title_layout, _ellipsize_text


struct WideMetrics(TextMetrics):
    def __init__(out self):
        pass

    def validate_family(self, family: StringSlice) raises:
        if not family == "Wide Test":
            raise Error("expected Wide Test font family")

    def width(self, text: StringSlice, font_size: Float64) raises -> Float64:
        var count = 0
        for _ in text.graphemes():
            count += 1
        return Float64(count) * font_size

    def height(self, font_size: Float64) raises -> Float64:
        return 1.5 * font_size


struct InvalidMetrics(TextMetrics):
    def __init__(out self):
        pass

    def validate_family(self, family: StringSlice) raises:
        pass

    def width(self, text: StringSlice, font_size: Float64) raises -> Float64:
        return Float64("nan")

    def height(self, font_size: Float64) raises -> Float64:
        return -1.0


def _plot() raises -> Plot:
    var x: List[Float64] = [0.0, 1.0, 2.0, 3.0]
    var y: List[Float64] = [1.0, 0.0, 3.0, 2.0]
    return Plot().with_line(x, y, label="Mixed 日本語")


def test_explicit_fallback_preserves_default_output() raises:
    var plot = _plot().with_title("測定 results")
    assert_equal(plot.render_svg(FallbackTextMetrics()), plot.render_svg())


def test_provider_drives_titles_tick_selection_and_legend_bounds() raises:
    var plot = (
        _plot()
        .with_size(6.0, 4.0)
        .with_title(
            "Long title with mixed 日本語 and Latin labels "
            "across repeated words and observations"
        )
        .with_theme(Theme().with_typography(Typography().with_family("Wide Test")))
    )
    var positions: List[Float64] = [0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0]
    var labels: List[String] = [
        "0000000",
        "0500000",
        "1000000",
        "1500000",
        "2000000",
        "2500000",
        "3000000",
    ]
    plot.xticks(positions, labels)
    var metrics = WideMetrics()
    var plan = plot.build_render_plan(metrics)
    var previous_right = -1.0
    var visible_ticks = 0
    var legend_right = 0.0
    var title_count = 0
    for command in plan.commands:
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
            visible_ticks += 1
        elif command.kind == CommandKind.LEGEND_BACKGROUND:
            legend_right = command.x1 + command.x2
        elif command.kind == CommandKind.LEGEND_TEXT:
            assert_true(
                command.x1 + metrics.width(command.text, command.font_size)
                < legend_right
            )
    assert_true(title_count == 2)
    assert_true(visible_ticks < len(positions))
    assert_true(visible_ticks > 1)


def test_provider_errors_and_invalid_measurements_propagate() raises:
    var plot = _plot()
    with assert_raises(contains="expected Wide Test font family"):
        _ = plot.build_render_plan(WideMetrics())
    with assert_raises(contains="text metrics height must be finite and positive"):
        _ = plot.build_render_plan(InvalidMetrics())


struct KerningMetrics(TextMetrics):
    def __init__(out self):
        pass

    def validate_family(self, family: StringSlice) raises:
        pass

    def width(self, text: StringSlice, font_size: Float64) raises -> Float64:
        var compressed = String(text).replace("AW", "Q")
        return Float64(compressed.byte_length()) * font_size

    def height(self, font_size: Float64) raises -> Float64:
        return font_size


def test_nonadditive_provider_measures_complete_candidate_lines() raises:
    var layout = _plain_title_layout(
        KerningMetrics(), "AWAWAWAWAWAWAWAWAWAW", 60.0, 10.0, 9.0
    )
    assert_equal(layout.font_size, 10.0)
    assert_equal(layout.first, "AWAWAWAWAW")
    assert_equal(layout.second, "AWAWAWAWAW")


struct ContractingMetrics(TextMetrics):
    def __init__(out self):
        pass

    def validate_family(self, family: StringSlice) raises:
        pass

    def width(self, text: StringSlice, font_size: Float64) raises -> Float64:
        if text == "…":
            return 0.4 * font_size
        if text == "A…":
            return 1.2 * font_size
        if text == "AV…":
            return 0.9 * font_size
        if text == "AVX…":
            return 0.3 * font_size
        return Float64(text.byte_length()) * font_size

    def height(self, font_size: Float64) raises -> Float64:
        return font_size


def test_nonadditive_fitting_allows_later_contracting_prefixes() raises:
    assert_equal(_ellipsize_text(ContractingMetrics(), "AVXYZ", 10.0, 10.0), "AVX…")


def test_nonadditive_fitting_can_contract_a_too_wide_ellipsis() raises:
    assert_equal(_ellipsize_text(ContractingMetrics(), "AVXYZ", 10.0, 3.5), "AVX…")


def test_title_never_returns_unmeasured_edge_whitespace() raises:
    var metrics = WideMetrics()
    var layout = _plain_title_layout(metrics, "          A          ", 10.0, 1.0, 1.0)
    assert_true(metrics.width(layout.first, layout.font_size) <= 10.0)
    assert_true(metrics.width(layout.second, layout.font_size) <= 10.0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
