"""Reproducible scalar-versus-batch affine scale throughput benchmark."""

from sen import LinearScale
from std.benchmark import keep
from std.collections import List
from std.sys import simd_width_of
from std.time import perf_counter_ns

comptime _ELEMENT_COUNT = 1 << 18
comptime _ROUNDS = 64
comptime _WARMUP_ROUNDS = 4
comptime _SAMPLE_COUNT = 7


def _map_scalar(
    scale: LinearScale,
    values: Span[Float64, ...],
    mut output: List[Float64],
):
    for index in range(len(values)):
        output[index] = scale.map(values[index])


def _fill_values() -> List[Float64]:
    var values = List[Float64](capacity=_ELEMENT_COUNT)
    for index in range(_ELEMENT_COUNT):
        values.append(Float64(index % 4093) * 0.03125 - 64.0)
    return values^


def _measure_scalar(
    scale: LinearScale,
    values: Span[Float64, ...],
    mut output: List[Float64],
) -> Int:
    for _ in range(_WARMUP_ROUNDS):
        _map_scalar(scale, values, output)
        keep(output)

    var best_elapsed_ns = 0
    for sample in range(_SAMPLE_COUNT):
        var started = perf_counter_ns()
        for _ in range(_ROUNDS):
            _map_scalar(scale, values, output)
            keep(output)
        var elapsed_ns = perf_counter_ns() - started
        if sample == 0 or elapsed_ns < best_elapsed_ns:
            best_elapsed_ns = elapsed_ns
    return best_elapsed_ns


def _measure_batch(
    scale: LinearScale,
    values: Span[Float64, ...],
    mut output: List[Float64],
) raises -> Int:
    for _ in range(_WARMUP_ROUNDS):
        scale.map_all(values, output)
        keep(output)

    var best_elapsed_ns = 0
    for sample in range(_SAMPLE_COUNT):
        var started = perf_counter_ns()
        for _ in range(_ROUNDS):
            scale.map_all(values, output)
            keep(output)
        var elapsed_ns = perf_counter_ns() - started
        if sample == 0 or elapsed_ns < best_elapsed_ns:
            best_elapsed_ns = elapsed_ns
    return best_elapsed_ns


def _print_result(name: StringLiteral, elapsed_ns: Int, checksum: Float64):
    var element_visits = _ELEMENT_COUNT * _ROUNDS
    print(
        "case=",
        name,
        " elapsed_ns=",
        elapsed_ns,
        " ns_per_element=",
        Float64(elapsed_ns) / Float64(element_visits),
        " elements_per_second=",
        Float64(element_visits) * 1.0e9 / Float64(elapsed_ns),
        " checksum=",
        checksum,
        sep="",
    )


def main() raises:
    var values = _fill_values()
    var output = List[Float64](length=len(values), fill=0.0)
    var scale = LinearScale(-64.0, 64.0, 1024.0, -256.0)

    print(
        'BENCH_HEADER sen linear_scale mojo=1.0.0 command="pixi run bench" ',
        "element_count=",
        _ELEMENT_COUNT,
        " rounds=",
        _ROUNDS,
        " warmup_rounds=",
        _WARMUP_ROUNDS,
        " samples=",
        _SAMPLE_COUNT,
        " statistic=minimum simd_width_float64=",
        simd_width_of[DType.float64](),
        sep="",
    )

    var scalar_elapsed_ns = _measure_scalar(scale, values, output)
    var scalar_checksum = output[0] + output[len(output) - 1]
    _print_result("scalar", scalar_elapsed_ns, scalar_checksum)

    var batch_elapsed_ns = _measure_batch(scale, values, output)
    var batch_checksum = output[0] + output[len(output) - 1]
    _print_result("batch", batch_elapsed_ns, batch_checksum)
