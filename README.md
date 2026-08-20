# Sen

> **Experimental — API may change before v1.0.**

Scientific plotting for Mojo.

## Scope

Sen owns plotting semantics independently of data-production libraries. The
current slice establishes renderer-neutral figure and series contracts before
adding a deterministic SVG backend.

The v0.1 plan proceeds through figures, axes, linear scales, ticks, legends,
line/scatter plots, and SVG output. Akari color integration remains deferred
until Akari's numeric and color-space contracts pass their documented gate.
The project is independently installable and does not require any application
from the wider ecosystem.

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

The exact stable Mojo compiler and all development dependencies are captured in
`pixi.lock`. Runtime and library code is Mojo-first and pure Mojo wherever
practical. Build-time data generation may use another language when justified,
but generated outputs must be deterministic, checksum-pinned, licensed, and
documented.

## Package

The Mojo import is `sen`. The eventual Conda distribution is
`mojo-sen`. Source lives under `src/sen/`, whose
`__init__.mojo` defines the package boundary.

The first public slice is deliberately renderer-neutral: constructor-validated
`PlotPoint` values, ordered and explicitly segmented `LineSeries` data with
validated bounds for nonempty series, and a `Figure` that owns line-series
semantics without SVG, native-window, or Akari coupling. Missing observations
start a new segment at the next finite point; NaN is never stored as a sentinel.
Because Mojo 1.0 struct storage remains externally mutable, mutation of
underscore-prefixed fields is out of contract. Constructors and public mutators
validate their inputs, reads trust established invariants, and each semantic
type provides an explicit `validate()` checkpoint for unusual low-level use.

```mojo
from sen import Figure, LineSeries, PlotPoint


def main() raises:
    var line = LineSeries()
    line.append(PlotPoint(0.0, 1.0))
    line.start_segment(PlotPoint(2.0, 3.0))  # Explicit gap before this point.
    var figure = Figure()
    figure.add_line(line)
```

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
