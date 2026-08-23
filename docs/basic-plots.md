# Basic 2D plot family

Sen exposes the common 2D plots through the same mutable `Plot` and `Figure`
vocabulary as `line` and `scatter`. Every call inserts exactly one logical
series, so automatic color, labels, legends, and SVG draw order follow call
order even when the plot lowers to many line segments or rectangles.

## Mutable and fluent construction

Every `Plot` mutator remains available for statement-oriented construction.
Its consuming counterpart returns an owned `Plot`, which supports direct
chains without returning references. Data and configuration calls add a
`with_` prefix; clear-axis operations use descriptive `with_auto_*` names:

```mojo
var svg = (
    Plot()
    .with_line(x, fitted, label="fit")
    .with_scatter(x, measured, label="measured")
    .with_title("Calibration")
    .with_grid()
    .render_svg()
)
```

This mapping covers `line`, `scatter`, `area`, `step`, `stem`, both `errorbar`
forms, numeric and categorical `bar`, both `histogram` forms, and all `Plot`
configuration calls. Each consuming call moves the same `Plot` through an
rvalue chain and delegates to the corresponding mutable mutator, preserving
validation, insertion order, data ownership, and rendered bytes. Use
`figure()` for an immutable borrow of the renderer-neutral figure,
`into_figure()` for an ownership transfer, or `build_render_plan()` to prepare
backend-neutral commands directly. Continuing a consuming chain from a named
plot uses an explicit transfer, such as `var updated = plot^.with_grid()`.

## Axes and prepared output

Both axes expose the same state transitions. `xlim(lo, hi)` / `ylim(lo, hi)`
set exact limits, while `clear_xlim()` / `clear_ylim()` restore automatic
bounds. `xticks(positions, labels)` and `yticks(positions, labels)` atomically
copy explicit ticks into the plot; `clear_xticks()` and `clear_yticks()` restore
automatic locations and numeric labels. Fluent chains use `with_xlim`,
`with_ylim`, `with_xticks`, `with_yticks`, and the corresponding `with_auto_*`
methods.

For workflows that inspect or reuse backend-neutral commands, build once and
encode separately:

```mojo
from sen import encode_svg, write_svg

var plan = plot.build_render_plan(720.0, 480.0)
var svg = encode_svg(plan)
write_svg("output/plot.svg", svg)
```

`Figure` and `Plot` both provide in-memory rendering and saving overloads with
explicit `Margins`. The old free `save_svg(path, svg)` remains a compatibility
alias for `write_svg`; it does not render a figure.

## Step and stem

`step(x, y, mode=StepMode.PRE)` accepts equal-length finite coordinate spans.
The nominal `PRE`, `POST`, and `MID` modes place the vertical transition before,
after, or halfway between adjacent x coordinates. The lowering creates one
connected `LineSeries` with no staging copy.

`stem(x, y, baseline=0.0)` creates one two-point segment per observation. The
finite baseline participates in bounds, so negative and nonzero baselines
autoscale correctly.

## Symmetric error bars

The three-span form adds vertical errors:

```mojo
plot.errorbar(x, y, y_error)
```

The four-span form adds both horizontal and vertical errors:

```mojo
plot.errorbar(x, y, x_error, y_error, cap_size=0.1)
```

Errors are absolute, symmetric magnitudes and must be finite and non-negative.
`cap_size` defaults to zero and is expressed in data units: x units for vertical
error caps and y units for horizontal error caps. All bar and cap segments share
one style, label, palette slot, and legend row.

## Numeric and categorical bars

`bar(x, height, width=0.8, baseline=0.0)` centers filled vertical bars on
numeric x positions. `width` is an absolute data-space width. Each signed height
extends from `baseline`, and rectangle edges are normalized before storage.

Passing a string span instead creates categorical bars at positions `0..n-1`:

```mojo
var category: List[String] = ["control", "variant A", "variant B"]
var score: List[Float64] = [72.0, 84.0, 91.0]
plot.bar(category, score, label="score")
```

The category names become explicit x tick labels. Later categorical bar calls
must reuse the exact ordered category domain, which keeps grouped overlays from
silently relabeling existing rectangles. Start a new `Plot` for a different
categorical domain. Lower-level users can call
`Figure.set_x_ticks(positions, labels)` and `Figure.clear_x_ticks()` directly
when intentionally managing tick semantics themselves.

## Histogram

The default overload bins the observed finite range into ten equal-width bins:

```mojo
plot.histogram(samples, bins=20, label="observations")
```

Pass an explicit inclusive range as two positional values:

```mojo
plot.histogram(samples, 0.0, 2.0, bins=20)
```

The bin count must be positive and a supplied range must have finite `lo < hi`.
Values outside it are ignored. Interior bins are left-inclusive and
right-exclusive; the final bin includes the upper range endpoint. Constant data
receives a finite range around its value rather than producing a degenerate
axis. If a floating-point range is too narrow to represent the requested number
of distinct bin edges, construction raises and recommends fewer bins or a wider
range.

Histogram work is `O(samples + bins)` and does not sort or copy the input.
Finite validation and min/max reduction use native-width SIMD chunks while
retaining deterministic first-invalid-index diagnostics; data-dependent bin
increments remain scalar scatter writes. Rectangle and segment buffers reserve
their final size once.

## Filled area

`area(x, y, baseline=0.0)` fills each connected boundary segment to one finite
constant y baseline. It accepts the same `MissingPolicy` as `line`: `SEGMENT`
emits one closed polygon per connected run, `DROP` joins remaining samples, and
`ERROR` rejects the first NaN. The baseline participates in autoscaling and a
zero baseline remains a sticky y-domain edge. Area outlines use the selected
line width and dash style; the fill uses the same deterministic palette color at
fixed 0.35 opacity. The area legend glyph preserves that opacity, outline width,
and dash style.

The semantic `AreaSeries` stores the line topology and baseline, while figure
lowering emits a backend-neutral area command. Another backend can therefore
render the same closed device-space polygon without reproducing missing-data,
bounds, scale, or layout rules.

## Rectangle primitive

`DataRectangle` and `RectangleSeries` are renderer-neutral filled-patch
semantics shared by bars and histograms. `RectangleSeries.from_edges` is the
batch fast path; `append` supports incremental construction. The SoA edge
buffers are validated at construction and moved into a `Figure` through
`add_rectangles`, making the primitive suitable for later heatmap lowering
without introducing a generic retained scene.

Run [the complete example](../examples/basic_plots.mojo) with `pixi run example`.
