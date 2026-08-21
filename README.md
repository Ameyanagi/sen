# Sen — sen (線, 'line')

> **Experimental — API may change before v1.0.**

Scientific plotting for Mojo.

## Install

In a [Pixi](https://pixi.sh/) project, add the ecosystem channel and package:

```sh
pixi project channel add https://ameyanagi.github.io/mojo-channel
pixi add mojo-sen
```

Then import `sen` from your Mojo code and run your own file:

```sh
pixi run mojo run my_plot.mojo
```

From a source checkout instead, run your file against `src/` directly:

```sh
pixi run mojo run -I src my_plot.mojo
```

## Quickstart

```mojo
from sen import Figure
from std.collections import List


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
    figure.save_svg("output/two_series.svg", width=720, height=480)
```

From a checkout, run it with `pixi run mojo run -I src my_plot.mojo` (or
`pixi run mojo run my_plot.mojo` with the package installed). It writes
`output/two_series.svg`, creating the directory if needed. `Figure.save_svg`
creates missing output directories and defaults to 640x480 when dimensions are
omitted.

`Figure.line` and `Figure.scatter` reject NaN by default. Pass
`MissingPolicy.SEGMENT` to split lines at missing observations or
`MissingPolicy.DROP` to remove them; scatter treats both policies as dropping
missing markers. The six-slot Tableau-10 palette is the automatic default. Use
`SeriesStyle(color="#rrggbb")` or `.with_color(...)` for an explicit color, and
`.with_line_width(...)` or `.with_marker_style(...)` for further styling.
Select `AxisKind.LOG10` with `set_x_scale` or `set_y_scale`; log data and limits
must be positive. Explicit limits are exact, `set_grid(True)` adds major
gridlines, and a legend renders if and only if at least one series has a
nonempty label unless `set_legend(LegendPosition.NONE)` suppresses it.

For custom margins or access to the SVG string itself, use
`render_svg(figure, width, height, margins)` and then the module-level
`save_svg(path, svg)` when you want to write it.

## Gapped semilog decay

This decay combines a logarithmic axis, a measurement gap, and explicit series
styling:

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

## CSS restyling

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
pixi run readme-check
pixi run check
pixi run example
```

`pixi run readme-check` compiles every fenced Mojo example in this README.
`pixi run check` runs it alongside formatting, tests, and package
precompilation. The installed-package smoke test runs separately through
`pixi run package` in the Linux CI package job and as a local release gate.

`pixi run example` writes `two_series.svg`, `semilog_decay.svg`, and
`gapped_signal.svg` under `output/`.

The exact stable Mojo compiler and all development dependencies are captured in
`pixi.lock`. Runtime and library code is Mojo-first and pure Mojo wherever
practical. Build-time data generation may use another language when justified,
but generated outputs must be deterministic, checksum-pinned, licensed, and
documented.

## Package

The Mojo import is `sen`. The Conda distribution is `mojo-sen`. Source lives
under `src/sen/`, whose `__init__.mojo` defines the package boundary.

Sen owns plotting semantics independently of data-production libraries. It
includes renderer-neutral figures, linear and base-10 logarithmic axes, ticks,
legends, line and scatter plots, and a deterministic SVG backend. Akari color
integration remains deferred until Akari's numeric and color-space contracts
pass their documented gate. Sen is independently installable and does not
require any application from the wider ecosystem.

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

## Documentation

See [the architecture](docs/architecture.md), [design principles](docs/design.md),
and [roadmap](docs/roadmap.md) before proposing a new dependency or feature.

## License

Licensed under either Apache-2.0 or MIT, at your option.
