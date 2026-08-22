# SVG performance profile

This profile was recorded on an Apple M4 running macOS 26.5.1 with Mojo 1.0.0
(`ed45d567`). The executable used the compiler's default `-O3` plus `-g1` line
tables. `pixi run bench-svg` performs three warmups and reports nearest-rank
p50/p95 over 21 samples. File I/O targets `/tmp` and is intentionally measured
after formatting so it never includes plan or string construction.

## Phase results

Representative optimized results from 2026-08-22:

| Workload | Phase | p50 | p95 |
|---|---:|---:|---:|
| line, 100,000 points | plan including scalar transforms | 1.666 ms | 1.801 ms |
| line, 100,000 points | SVG formatting | 9.785 ms | 11.115 ms |
| line, 100,000 points | file I/O | 0.459 ms | 0.868 ms |
| scatter, 10,000 points | plan including scalar transforms | 0.367 ms | 0.374 ms |
| scatter, 10,000 points | SVG formatting | 2.299 ms | 2.340 ms |
| scatter, 10,000 points | file I/O | 0.200 ms | 0.405 ms |
| rectangles, 10,000 | plan including scalar transforms | 0.672 ms | 0.803 ms |
| rectangles, 10,000 | SVG formatting | 3.101 ms | 3.285 ms |
| rectangles, 10,000 | file I/O | 0.300 ms | 0.794 ms |
| area, 10,000 points | plan including scalar transforms | 0.185 ms | 0.204 ms |
| area, 10,000 points | SVG formatting | 1.112 ms | 1.192 ms |
| area, 10,000 points | file I/O | 0.182 ms | 0.340 ms |

The plan phase above is the production `build_render_plan` call. It constructs
each axis scale once, uses the real ordered scalar coordinate maps, allocates
each line/area segment buffer at its known final capacity, and constructs the
commands consumed by SVG. It is not an isolated `map_all` result. The SIMD
`LinearScale.map_all` microbenchmark remains available through `pixi run bench`,
but is intentionally excluded from this phase table.

`xctrace` Time Profiler sampled the compiled process at 1 ms. Before the change,
the line workload measured 16.735 ms p50 / 20.397 ms p95 in formatting and the
profile repeatedly landed in `_format_svg_number`, `_format_decimal`, integer
formatting, `String._iadd`, and mutable string buffer operations. The isolated
one-axis SIMD experiment was not the renderer's transform path, so it is no
longer reported as a phase or used to justify renderer latency.

The optimized encoder appends the fixed three-decimal representation directly
to the destination string instead of allocating one temporary `String` per
coordinate. Every pre-existing SVG golden remained byte-exact. Against the same
baseline, representative line-formatting latency fell by 38.6% at p50 and
46.3% at p95. The after-profile contains `_append_svg_number` and destination
buffer writes but no sampled `_format_svg_number` or `_format_decimal` hot frame.

The next likely encoder optimization is SVG-string capacity planning or a
dedicated byte writer, but only after a new profile demonstrates that
growth/copying dominates. Point decimation remains a separate visual-semantics
feature and is not silently applied by this exact renderer.

A final `xctrace` Time Profiler capture of `.pixi/sen-svg-profile` on the same
machine sampled the real `build_render_plan`, `_AxisMapper.map`, segment access,
command-list append, `_encode_svg`, and `_append_svg_number` frames. That capture
is the basis for keeping scale construction outside the point loops and exact
segment-capacity reservation; it did not show evidence for inserting a separate
SIMD staging-buffer pass into ordered lowering.
