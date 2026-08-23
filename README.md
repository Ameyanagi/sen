# Sen — sen (線, 'line')

> **Experimental — API may change before v1.0.**

Scientific plotting for Mojo.

## Install

In a [Pixi](https://pixi.sh/) project, configure the ecosystem, Mojo, and
Conda Forge channels in `pixi.toml`:

```toml
[workspace]
channels = [
    "https://ameyanagi.github.io/mojo-channel",
    "https://conda.modular.com/max",
    "conda-forge",
]
```

Then add the package:

```sh
pixi add mojo-sen
```

Then import `sen` from your Mojo code and run your own file:

```sh
pixi run mojo run my_plot.mojo
```

From a source checkout instead, install the locked environment and run your
file against `src/` directly:

```sh
pixi install --locked
pixi run mojo run -I src my_plot.mojo
```

## Quickstart

```mojo
from sen import Plot
from std.collections import List


def main() raises:
    var x: List[Float64] = [0.0, 1.0, 2.0, 3.0, 4.0]
    var fitted: List[Float64] = [1.0, 2.0, 3.0, 4.0, 5.0]
    var measured: List[Float64] = [0.9, 2.2, 2.8, 4.1, 5.2]

    var plot = (
        Plot()
        .with_line(x, fitted, label="fit")
        .with_scatter(x, measured, label="measured")
        .with_title("Calibration")
        .with_xlabel("input")
        .with_ylabel("response")
        .with_grid()
    )

    plot.save_svg("output/two_series.svg", width=720.0, height=480.0)
```

From a checkout, run it with `pixi run mojo run -I src my_plot.mojo` (or
`pixi run mojo run my_plot.mojo` with the package installed). It writes
`output/two_series.svg`, creating the directory if needed. `Plot.render_svg()`
returns the SVG document when an in-memory result is more convenient.
`Plot.save_svg(path)` renders once at 640x480 and replaces `path`; optional
width and height arguments select a different size. The lower-level `Figure`,
free `render_svg`, and compatibility `save_svg(path, svg)` APIs remain
available. New code that already has SVG bytes should use the unambiguous
`write_svg(path, svg)` name.

Every `Plot` data and configuration mutator has a consuming `with_*`
counterpart for fluent construction. The consuming methods return an owned
`Plot`, not a reference, so chaining an rvalue moves the same plot through the
expression without copying its retained series. The original mutable calls
remain supported when incremental control flow is clearer:

```mojo
from sen import Plot
from std.collections import List


def main() raises:
    var x: List[Float64] = [0.0, 1.0]
    var y: List[Float64] = [1.0, 2.0]
    var plot = Plot()
    plot.line(x, y)
    plot.title("Mutable construction")
    var svg = plot.render_svg()
```

To continue a consuming chain from a named plot without copying it, transfer
the value explicitly: `var updated = plot^.with_grid()`.

`Plot.figure()` borrows the underlying renderer-neutral `Figure`, while
`into_figure()` consumes the plot and transfers that figure without copying its
series. Passing an owned `Figure` to `Plot(figure^)` performs the reverse
transfer. `Plot.build_render_plan()` prepares a backend-neutral plan; encode it
without repeating layout work using `encode_svg(plan)`, then persist the result
with `write_svg(path, svg)`. The geometry overloads on `build_render_plan`,
`render_svg`, and `save_svg` accept explicit `Margins` when layout control is
required.

## Scope

Sen owns plotting semantics independently of data-production libraries. The
current slice includes renderer-neutral figures and render plans, linear and
base-10 logarithmic axes, ticks, legends, line/scatter plots, segmented areas,
step and stem plots, symmetric error bars, filled numeric/categorical bars,
equal-width histograms, and a
deterministic SVG backend. Akari color integration remains deferred until
Akari's numeric and color-space contracts pass their documented gate. The
project is independently installable and does not require any application from
the wider ecosystem.

`Plot.line` and `Plot.scatter` reject NaN by default. Pass
`MissingPolicy.SEGMENT` to split lines at missing observations or
`MissingPolicy.DROP` to remove them; scatter treats both policies as dropping
missing markers. Automatic colors cycle deterministically through the first six
Tableau-10 colors in insertion order. Use `SeriesStyle(color="#rrggbb")` or
`.with_color(...)` for an explicit color, and `.with_line_width(...)` or
`.with_marker_style(...)` for further styling. Select `AxisKind.LOG10` with
`xscale` or `yscale`; log data and limits must be positive. Explicit limits are
exact and `clear_xlim()` / `clear_ylim()` restore automatic bounds. `xticks()`
and `yticks()` install owned positions and labels; their matching clear calls
restore automatic ticks. `grid()` adds major gridlines, and a legend renders if
and only if at least one series has a nonempty label unless
`legend(LegendPosition.NONE)` suppresses it.

The complete basic family uses the same stateful vocabulary:
`step(..., mode=StepMode.MID)`, `stem(..., baseline=0.0)`,
`errorbar(x, y, y_error)` or `errorbar(x, y, x_error, y_error)`,
`area(x, y, baseline=0.0)`, `bar(x, height)`, `bar(categories, height)`, and
`histogram(data, bins=10)`.
Prefix any of these calls with `with_` to use it in a fluent `Plot` chain.
See [Basic 2D plots](docs/basic-plots.md) for validation, range, category, and
performance contracts, and [the runnable example](examples/basic_plots.mojo)
for SVG output.

## Gapped semilog decay

This lower-level example combines a logarithmic axis, a measurement gap, and
explicit series styling:

```mojo
from sen import AxisKind, Figure, LineStyle, MissingPolicy, SeriesStyle
from std.collections import List


def main() raises:
    var time: List[Float64] = [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0]
    var amplitude: List[Float64] = [
        1000.0, 100.0, Float64("nan"), Float64("nan"), 10.0, 1.0, 0.1
    ]
    var style = (
        SeriesStyle(color="#8b1e3f")
        .with_line_style(LineStyle.DASHED)
        .with_line_width(2.5)
    )
    var figure = Figure()
    figure.line(
        time, amplitude, label="decay", style=style, missing=MissingPolicy.SEGMENT
    )
    figure.set_y_scale(AxisKind.LOG10)
    figure.set_title("Gapped decay")
    figure.set_grid(True)
    figure.save_svg("output/decay.svg")
```

The omitted dimensions use the default 640x480 canvas.

SVG drawing elements retain inline presentation attributes and expose stable
`sen-*` classes: backgrounds, frames, axes, ticks, tick labels, titles, axis
labels, grids, insertion-indexed series, and legend elements. An external
stylesheet can override them:

```css
.sen-background { fill: #fffdf8; }
.sen-grid { stroke: #d8d3c8; }
.sen-series-0 { stroke: #8b1e3f; }
```

## Development

Install [Pixi](https://pixi.sh/), then run:

```sh
pixi install --locked
pixi run check
pixi run example
```

`pixi run check` covers formatting, tests, and package precompilation. The
installed-package smoke test runs separately through `pixi run package` in CI,
on every supported native target for releases, and as a local release gate.

`pixi run bench-svg` builds and runs the large-series p50/p95 phase benchmark.
See [the profiling report](docs/performance.md) for the Time Profiler procedure,
results, and optimization rationale.

`pixi run example` writes the line/scatter examples plus
`basic-step-errorbar.svg`, `basic-bars.svg`, `basic-histogram.svg`, and
`basic-area.svg` under `output/`.

The exact stable Mojo compiler and all development dependencies are captured in
`pixi.lock`. Runtime and library code is Mojo-first and pure Mojo wherever
practical. Build-time data generation may use another language when justified,
but generated outputs must be deterministic, checksum-pinned, licensed, and
documented.

## Package

The Mojo import is `sen`. The Conda distribution is `mojo-sen`. Source lives
under `src/sen/`, whose
`__init__.mojo` defines the package boundary.

The semantic layer remains renderer-neutral: constructor-validated points,
ordered line, scatter, area, and rectangle series, explicit gap topology,
styles, axis state, and a `Figure` that owns draw order without native-window or
Akari coupling. The package-root
`build_render_plan(figure, width, height, margins)` API produces ordered
device-space commands for any backend; the SVG backend only encodes that same
plan. `CommandKind`, `PlanPoint`, `DrawCommand`, and `RenderPlan` are exported,
validated, equatable semantic values. NaN is never stored as a sentinel.
Because Mojo 1.0 struct storage remains externally mutable, mutation of
underscore-prefixed fields is out of contract. Constructors and public mutators
validate their inputs, reads trust established invariants, and semantic types
provide explicit `validate()` checkpoints for unusual low-level use.

## Repository map

- `src/sen/`: library or application source
- `tests/`: TestSuite unit, reference-value, and invariant tests
- `examples/`: small compilable usage programs
- `benchmarks/`: reproducible methodology and later benchmark programs
- `docs/`: architecture, design, compatibility, roadmap, and release policy
- `conda.recipe/`: local Rattler build recipe

See [the architecture](docs/architecture.md), [design principles](docs/design.md),
and [roadmap](docs/roadmap.md) before proposing a new dependency or feature.

## License

Licensed under either Apache-2.0 or MIT, at your option.
