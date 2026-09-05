# Source API (unreleased)

These APIs require a source checkout. They are not in the immutable `mojo-sen=0.1.0`
channel package. Run examples using `pixi run mojo run -I src my_plot.mojo`.
For the installed package, use the [README quickstart](../README.md).

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
        .with_size(7.2, 4.8)
        .with_grid()
    )

    plot.save_svg("output/two_series.svg")
```

From a checkout, run it with `pixi run mojo run -I src my_plot.mojo` (or
`pixi run mojo run my_plot.mojo` with the package installed). It writes
`output/two_series.svg`, creating the directory if needed. `Plot.render_svg()`
returns the SVG document when an in-memory result is more convenient.
`Plot.save_svg(path)` uses the stored physical size (6.4 by 4.8 inches by
default) and replaces `path`. The lower-level `Figure`, free `render_svg`, and
compatibility `save_svg(path, svg)` APIs remain available. New code that
already has SVG bytes should use the unambiguous `write_svg(path, svg)` name.

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
required. Their numeric width and height are legacy logical-coordinate
overloads; prefer `with_size(width_inches, height_inches)` in new code.

## Size, DPI, and design

Physical size and export resolution are independent. `with_size(8.0, 5.0)`
sets inches. `with_dpi(300.0)` changes the pixel dimensions requested by a
future raster backend without changing SVG geometry, typography, or physical
size. `with_size_px(2400, 1500)` converts pixels through the current DPI while
leaving that DPI unchanged. The no-argument SVG renderer therefore emits a
physical root and stable logical view box such as:

```xml
<svg width="8in" height="5in" viewBox="0 0 800 500">
```

Typography, strokes, and marker sizes use physical point sizes and are
converted once into the DPI-independent logical coordinate space. Automatic
margins are measured from the title, axis labels, tick labels, and legend.
Every tick and grid mark is emitted; overlapping labels are deterministically
selected from their mapped extents. Long titles are fitted, and the default
`LegendPosition.BEST` scores all four plot corners against series geometry.

The default font stack covers common Japanese, Simplified and Traditional
Chinese, and Korean system fonts. Sen preserves Unicode text exactly and uses
deterministic CJK/emoji-aware fallback metrics for layout. A theme can be
changed without affecting data or geometry:

```mojo
from sen import Plot, Theme


def main() raises:
    var plot = Plot().with_theme(Theme.dark()).with_size(7.0, 4.5)
    plot.validate()
```

### Optional Typst math

Plain text remains the zero-dependency default. Mark only mathematical roles
that should be compiled by a local [Typst](https://typst.app/) executable:

```mojo
from sen import Plot, Text, TypstOptions
from std.collections import List


def main() raises:
    var x: List[Float64] = [0.0, 1.0, 2.0]
    var y: List[Float64] = [0.0, 1.0, 4.0]
    var plot = (
        Plot()
        .with_line(x, y)
        .with_title(Text.typst_math("$ y = x^2 $"))
        .with_xlabel(Text.typst_math("$ x $"))
    )
    plot.save_svg("output/math.svg", TypstOptions())
```

`Text.typst_math` accepts trusted Typst markup, including its `$...$` math
delimiters; it is not a LaTeX compatibility layer. Sen invokes Typst only when
rendering a marked value. The compiler runs in a fresh temporary root with a
wall timeout, captured diagnostics, shell-quoted paths, and bounded source and
SVG sizes. Configure a non-default executable or tighter limits with
`TypstOptions`. Plain strings and `Text.plain(...)` never start or validate a
Typst process.

Every embedded Typst resource ID includes its deterministic render-command
index, so repeated mathematical roles within one figure remain unique. When
several complete Sen SVG figures are inlined into the same document, give each
figure its own validated ID prefix while preserving reproducible output:

```mojo
from sen import TypstOptions


def main() raises:
    var options = TypstOptions().with_id_prefix("results-panel-2")
    options.validate()
```

Prefixes use the safe ASCII form `[A-Za-z_][A-Za-z0-9_-]*` and are limited to
64 bytes. Pass the configured options to `render_svg` or `save_svg`; rendering
the same figure with the same options remains byte-for-byte deterministic.

### CJK locale

Choose a locale when shared Han ideographs must use language-correct glyph
forms. This also emits matching SVG `lang` and `xml:lang` metadata and reorders
the fallback fonts:

```mojo
from sen import TextLocale, Theme, Typography


def main() raises:
    var typography = Typography().with_locale(TextLocale.ZH_HANT)
    var theme = Theme().with_typography(typography)
    theme.validate()
```

The supported explicit values are `JA`, `ZH_HANS`, `ZH_HANT`, and `KO`;
`AUTO` preserves the locale-neutral fallback order.

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
`.with_marker_style(...)` for further styling. Marker size and line width are
specified in points; opacity, line caps, and joins are also chainable on
`SeriesStyle`. Select `AxisKind.LOG10` with
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
See [Basic 2D plots](basic-plots.md) for validation, range, category, and
performance contracts, and [the runnable example](../examples/basic_plots.mojo)
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

The omitted dimensions use the default 6.4-by-4.8-inch canvas and a stable
640-by-480 logical SVG view box.

SVG drawing elements retain inline presentation attributes and expose stable
`sen-*` classes: backgrounds, frames, axes, ticks, tick labels, titles, axis
labels, grids, insertion-indexed series, and legend elements. An external
stylesheet can override them:

```css
.sen-background { fill: #fffdf8; }
.sen-grid { stroke: #d8d3c8; }
.sen-series-0 { stroke: #8b1e3f; }
```


## Accessible descriptions

Use `plot.description(text)` or consuming `with_description(text)` to explain
axes, series, or an author-approved takeaway. Sen never infers a scientific
conclusion. `Figure.set_accessible_description` and
`RenderPlan.accessible_description` expose the same optional plain-text
metadata; the empty string restores the generic default. XML escaping and
forbidden-scalar validation match other SVG text.

```mojo
from sen import Plot


def main() raises:
    var x: List[Float64] = [0.0, 1.0, 2.0]
    var y: List[Float64] = [1.0, 2.0, 3.0]
    var plot = (
        Plot().with_line(x, y, label="fit")
        .with_title("Calibration")
        .with_description(
            "Input on the horizontal axis and response on the vertical axis. "
            "A line shows the fitted series."
        )
    )
    plot.save_svg("output/accessible.svg")
```

`<svg role="img">` exposes the title as its accessible name and the description
as its accessible description. `scripts/check-svg-browser.cjs` checks Chromium's
actual accessibility tree; `examples/accessible_plot.mojo` is the two-series
example used by that inspection.

## Measured fonts

`TextMetrics` is a small synchronous contract: `validate_family`, complete-run
`width(text, font_size)`, and `height(font_size)` in SVG logical units. All
measurements must be finite; widths are nonnegative and line-box heights are
positive. Measurements must scale linearly with font size. Errors propagate
before a plan is returned. The caller must load the same font and shaping
configuration in the SVG viewer. `FallbackTextMetrics` preserves the default
font-independent deterministic estimates.

Pass a provider to `build_render_plan(figure, metrics)` or
`plot.build_render_plan(metrics)`, then call `encode_svg(plan)`. Explicit geometry
is available through `build_render_plan(figure, width, height, margins, metrics)`.
`plot.render_svg(metrics)` combines the two steps. Titles and axis labels fit
whole measured runs; tick selection and legends use the same provider.
Providers may opt into `additive_graphemes()` when independent grapheme widths
are exactly additive, retaining linear title fitting. Shaping providers keep
the default `False`, so candidate lines are measured as complete runs.

The optional [`sen_kumihan` adapter](font-metrics.md) uses pinned published font
parsing and horizontal advances. It is packaged as source alongside `sen` and
requires an explicit Kumihan installation only when imported.

## Repeated Typst fragments

One SVG encoding caches at most 64 raw fragments / 8 MiB of source and SVG bytes.
The key includes the exact source, width, height, font size, foreground,
executable, timeout, byte limits, and ID prefix. Full caches clear before the next
admission; oversized entries are not retained. Every placement gets its own
namespaced IDs after lookup. A second render starts with an empty cache. Failures
and resource-limit checks are not cached. See the [benchmark](../benchmarks/README.md).
