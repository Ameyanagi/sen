# Benchmarks and profiling

Run the native-width linear-scale microbenchmark with `pixi run bench`. Run the
compiled end-to-end SVG phase benchmark with `pixi run bench-svg`. The latter
builds at the compiler's default `-O3` with line tables, performs three warmups,
and reports nearest-rank p50/p95 over 21 samples for:

- real render-plan construction, including its scalar coordinate maps, for a
  100,000-point line, 10,000 markers, 10,000 rectangles, and a 10,000-point
  filled area;
- deterministic SVG formatting from an already-built plan; and
- replacement-file I/O of the already-built SVG.

`pixi run bench` separately measures the public `LinearScale.map_all` SIMD
kernel. That standalone kernel is useful scale evidence, but is deliberately
not labeled as a phase of figure lowering.

On macOS, capture a real sampling profile of the same compiled workload:

```sh
pixi run mojo build -I src -g1 benchmarks/bench_svg_pipeline.mojo \
  -o .pixi/sen-svg-profile
xcrun xctrace record --template 'Time Profiler' \
  --output /tmp/sen-svg.trace --launch -- .pixi/sen-svg-profile
```

The benchmark writes only `/tmp/sen-svg-profile.svg`. Results are development
evidence, not permanent marketing claims. Record CPU, OS, Mojo version, compiler
options, warmup, sample count, statistic, and exact command when quoting them.


## Render-local Typst cache

Run `pixi run --locked mojo run -I src benchmarks/bench_typst_cache.mojo`.
The fixture creates 50 identical math title commands and compares 50 calls to
the unchanged bounded compiler boundary against one complete cached SVG render.
The counting tests independently assert one subprocess per distinct input and
one fresh subprocess in the next render. The fake compiler writes deterministic
SVG immediately, isolating process overhead; actual Typst compilation savings
will depend on the input and host.

2026-09-05, Apple M4 / macOS ARM64, pinned Mojo 1.0.0, optimized `mojo run`: 50 uncached
calls took **1837.494 ms**; full cached encoding took **35.239 ms** and emitted
22,150 bytes (about 52x less wall time for this synthetic workload). No timeout,
source/output limit, or failure propagation gate was removed.
