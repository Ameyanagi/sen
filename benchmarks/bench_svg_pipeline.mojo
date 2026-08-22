"""Profile-oriented p50/p95 benchmark for Sen's compiled SVG pipeline."""

from sen import Figure, build_render_plan
from sen.svg import _encode_svg, save_svg
from sen.layout import Margins
from std.benchmark import keep
from std.collections import List
from std.time import perf_counter_ns


comptime _LINE_POINTS = 100_000
comptime _SCATTER_POINTS = 10_000
comptime _RECTANGLES = 10_000
comptime _AREA_POINTS = 10_000
comptime _SAMPLES = 21
comptime _WARMUPS = 3


def _percentile(samples: List[Int], numerator: Int, denominator: Int) -> Int:
    """Return a deterministic nearest-rank percentile after insertion sorting."""
    var ordered = samples.copy()
    for index in range(1, len(ordered)):
        var value = ordered[index]
        var insertion = index
        while insertion > 0 and ordered[insertion - 1] > value:
            ordered[insertion] = ordered[insertion - 1]
            insertion -= 1
        ordered[insertion] = value
    var rank = (numerator * len(ordered) + denominator - 1) // denominator - 1
    return ordered[max(0, min(rank, len(ordered) - 1))]


def _print_samples(name: StringLiteral, phase: StringLiteral, samples: List[Int]):
    print(
        "case=",
        name,
        " phase=",
        phase,
        " p50_ns=",
        _percentile(samples, 50, 100),
        " p95_ns=",
        _percentile(samples, 95, 100),
        sep="",
    )


def _x_coordinates(count: Int) -> List[Float64]:
    var x = List[Float64](capacity=count)
    for index in range(count):
        x.append(Float64(index))
    return x^


def _y_coordinates(count: Int) -> List[Float64]:
    var y = List[Float64](capacity=count)
    for index in range(count):
        y.append(Float64((index * 17) % 1009) * 0.125 - 50.0)
    return y^


def _line_figure() raises -> Figure:
    var x = _x_coordinates(_LINE_POINTS)
    var y = _y_coordinates(_LINE_POINTS)
    var figure = Figure()
    figure.line(x, y)
    return figure^


def _scatter_figure() raises -> Figure:
    var x = _x_coordinates(_SCATTER_POINTS)
    var y = _y_coordinates(_SCATTER_POINTS)
    var figure = Figure()
    figure.scatter(x, y)
    return figure^


def _rectangle_figure() raises -> Figure:
    var x = _x_coordinates(_RECTANGLES)
    var y = _y_coordinates(_RECTANGLES)
    var figure = Figure()
    figure.bar(x, y, width=0.9)
    return figure^


def _area_figure() raises -> Figure:
    var x = _x_coordinates(_AREA_POINTS)
    var y = _y_coordinates(_AREA_POINTS)
    var figure = Figure()
    figure.area(x, y, baseline=-50.0)
    return figure^


def _bench_case[name: StringLiteral](figure: Figure) raises:
    var margins = Margins(40.0, 12.0, 12.0, 28.0)
    for _ in range(_WARMUPS):
        var warm_plan = build_render_plan(figure, 800.0, 480.0, margins)
        var warm_svg = _encode_svg(warm_plan)
        keep(warm_svg)

    var plan_samples = List[Int](capacity=_SAMPLES)
    var format_samples = List[Int](capacity=_SAMPLES)
    var io_samples = List[Int](capacity=_SAMPLES)
    for _ in range(_SAMPLES):
        var started = perf_counter_ns()
        var plan = build_render_plan(figure, 800.0, 480.0, margins)
        plan_samples.append(perf_counter_ns() - started)

        started = perf_counter_ns()
        var svg = _encode_svg(plan)
        format_samples.append(perf_counter_ns() - started)
        keep(svg)

        started = perf_counter_ns()
        save_svg("/tmp/sen-svg-profile.svg", svg)
        io_samples.append(perf_counter_ns() - started)

    _print_samples(name, "plan_including_scalar_transforms", plan_samples)
    _print_samples(name, "format", format_samples)
    _print_samples(name, "io", io_samples)


def main() raises:
    print(
        "BENCH_HEADER sen svg_pipeline mojo=1.0.0 samples=",
        _SAMPLES,
        " warmups=",
        _WARMUPS,
        " statistic=p50,p95",
        sep="",
    )
    _bench_case["line_100k"](_line_figure())
    _bench_case["scatter_10k"](_scatter_figure())
    _bench_case["rectangles_10k"](_rectangle_figure())
    _bench_case["area_10k"](_area_figure())
