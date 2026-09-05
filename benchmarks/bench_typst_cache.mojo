"""Compare repeated bounded compiler calls with render-local reuse."""
from sen import Plot, Text, TypstOptions, CommandKind, encode_svg
from sen.typst import _compile_typst_svg
from std.time import perf_counter_ns


def main() raises:
    var x: List[Float64] = [0.0, 1.0]
    var y: List[Float64] = [0.0, 1.0]
    var plan = (
        Plot()
        .with_line(x, y)
        .with_title(Text.typst_math("$ x^2 $"))
        .build_render_plan()
    )
    var title_index = -1
    for index in range(plan.command_count()):
        if plan.commands[index].kind == CommandKind.TITLE:
            title_index = index
    for _ in range(49):
        plan.commands.append(plan.commands[title_index].copy())
    var options = TypstOptions(executable="tests/fixtures/fake_typst.sh")
    var font_size = plan.commands[title_index].font_size
    var width = plan.plot_width * 0.72
    var height = font_size * 2.4 * 0.72
    var started = perf_counter_ns()
    for _ in range(50):
        _ = _compile_typst_svg(
            "$ x^2 $", font_size * 0.72, "#000000", width, height, options
        )
    var uncached_ns = perf_counter_ns() - started
    started = perf_counter_ns()
    var svg = encode_svg(plan, options)
    var cached_ns = perf_counter_ns() - started
    print(
        "placements=50 uncached_ms=",
        Float64(uncached_ns) / 1e6,
        " cached_full_render_ms=",
        Float64(cached_ns) / 1e6,
        " svg_bytes=",
        svg.byte_length(),
    )
