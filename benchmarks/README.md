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
