# Sen — sen (線, 'line')

> **Experimental — API may change before v1.0.**

Scientific plotting for Mojo.

## Scope

Sen owns plotting semantics independently of data-production libraries. The
current slice includes renderer-neutral figures, linear and base-10 logarithmic
axes, ticks, legends, line/scatter plots, and a deterministic SVG backend. Akari
color integration remains deferred until Akari's numeric and color-space
contracts pass their documented gate. The project is independently installable
and does not require any application from the wider ecosystem.

## Quickstart

```mojo
from sen import Figure, render_svg, save_svg
from std.collections import List
from std.os import makedirs


def main() raises:
    var x: List[Float64] = [0.0, 1.0, 2.0, 3.0, 4.0]
    var fitted: List[Float64] = [1.0, 2.0, 3.0, 4.0, 5.0]
    var measured: List[Float64] = [0.9, 2.2, 2.8, 4.1, 5.2]

    var figure = Figure()
    figure.line(x, fitted, label="fit")
    figure.scatter(x, measured, label="measured")
    figure.set_title("Calibration")
    figure.set_x_label("input")
    figure.set_y_label("response")
    figure.set_grid(True)

    makedirs("output", exist_ok=True)
    save_svg("output/two_series.svg", render_svg(figure, 720.0, 480.0))
```

`Figure.line` and `Figure.scatter` reject NaN by default. Pass
`MissingPolicy.SEGMENT` to split lines at missing observations or
`MissingPolicy.DROP` to remove them; scatter treats both policies as dropping
missing markers. Automatic colors cycle deterministically through the first six
Tableau-10 colors in insertion order. Select `AxisKind.LOG10` with
`set_x_scale` or `set_y_scale`; log data and limits must be positive. Explicit
limits are exact, `set_grid(True)` adds major gridlines, and a legend renders if
and only if at least one series has a nonempty label unless
`set_legend(LegendPosition.NONE)` suppresses it.

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
installed-package smoke test runs separately through `pixi run package` in the
Linux CI package job and as a local release gate.

`pixi run example` writes `two_series.svg`, `semilog_decay.svg`, and
`gapped_signal.svg` under `output/`.

The exact stable Mojo compiler and all development dependencies are captured in
`pixi.lock`. Runtime and library code is Mojo-first and pure Mojo wherever
practical. Build-time data generation may use another language when justified,
but generated outputs must be deterministic, checksum-pinned, licensed, and
documented.

## Package

The Mojo import is `sen`. The eventual Conda distribution is
`mojo-sen`. Source lives under `src/sen/`, whose
`__init__.mojo` defines the package boundary.

The semantic layer remains renderer-neutral: constructor-validated points,
ordered line and scatter series, explicit gap topology, styles, axis state, and
a `Figure` that owns draw order without native-window or Akari coupling. The SVG
backend is a separate deterministic adapter. NaN is never stored as a sentinel.
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
