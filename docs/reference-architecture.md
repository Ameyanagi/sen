# Reference architecture

This document records primary-source design evidence for Sen. The references
were shallow-cloned and inspected at the exact revisions below. Sen adopts
mathematical and architectural ideas where they fit Mojo, but does not copy
source, generated code, tests, or runtime dependencies from these projects.

## Primary-reference ledger

| Reference | Revision inspected | License | Material inspected | Architectural value |
| --- | --- | --- | --- | --- |
| [Plotters](https://github.com/plotters-rs/plotters/tree/c63248e0cf7c611185361ac492003e8a87d52ea8) | `c63248e0cf7c611185361ac492003e8a87d52ea8`, 2026-03-17 | MIT | [`plotters-backend/src/lib.rs`](https://github.com/plotters-rs/plotters/blob/c63248e0cf7c611185361ac492003e8a87d52ea8/plotters-backend/src/lib.rs), [`drawing/area.rs`](https://github.com/plotters-rs/plotters/blob/c63248e0cf7c611185361ac492003e8a87d52ea8/plotters/src/drawing/area.rs), chart/coordinate/series modules, and [`plotters-svg/src/svg.rs`](https://github.com/plotters-rs/plotters/blob/c63248e0cf7c611185361ac492003e8a87d52ea8/plotters-svg/src/svg.rs) | Typed coordinate translation, small drawing-backend primitives, error propagation, owned line data, and SVG-to-string output |
| [Makie.jl](https://github.com/MakieOrg/Makie.jl/tree/0953853105b0fafbdd4583aa5e21e975ec687311) | `0953853105b0fafbdd4583aa5e21e975ec687311`, 2026-08-13 | MIT | [`Makie/src/figures.jl`](https://github.com/MakieOrg/Makie.jl/blob/0953853105b0fafbdd4583aa5e21e975ec687311/Makie/src/figures.jl), [`coretypes.jl`](https://github.com/MakieOrg/Makie.jl/blob/0953853105b0fafbdd4583aa5e21e975ec687311/Makie/src/coretypes.jl), scenes, layout, axis, limit, plot, and backend interfaces | Figure/layout/axis separation, plot trees, combined data limits, explicit screen backends, and the cost of reactive scene complexity |
| [Vega-Lite](https://github.com/vega/vega-lite/tree/4c03edb62dbc1cee09a5ab3b25efb1fce367de54) | `4c03edb62dbc1cee09a5ab3b25efb1fce367de54`, 2026-08-14 | BSD-3-Clause | typed spec/encoding modules, [`src/invalid.ts`](https://github.com/vega/vega-lite/blob/4c03edb62dbc1cee09a5ab3b25efb1fce367de54/src/invalid.ts), and [`src/compile/compile.ts`](https://github.com/vega/vega-lite/blob/4c03edb62dbc1cee09a5ab3b25efb1fce367de54/src/compile/compile.ts) plus model/component assembly | Declarative semantic input, normalize/parse/assemble stages, explicit invalid-data policy, and a renderer-neutral intermediate model |
| [Matplotlib](https://github.com/matplotlib/matplotlib/tree/0c9b7e2afe620bf6ca6e3e1761d5cdb6065852aa) | `0c9b7e2afe620bf6ca6e3e1761d5cdb6065852aa`, 2026-08-19 | Matplotlib License | Figure/Axes/Artist, scale/ticker/transform modules, [`backend_bases.py`](https://github.com/matplotlib/matplotlib/blob/0c9b7e2afe620bf6ca6e3e1761d5cdb6065852aa/lib/matplotlib/backend_bases.py), and [`backend_svg.py`](https://github.com/matplotlib/matplotlib/blob/0c9b7e2afe620bf6ca6e3e1761d5cdb6065852aa/lib/matplotlib/backends/backend_svg.py) | Mature Figure/Axes/Artist/Renderer layering, ordered drawing, clipping, backend specialization, and SVG reproducibility pitfalls |

The local research clones remain outside the Sen repository and are not build
inputs. Licenses in this table describe the inspected projects. Sen remains
licensed under MIT OR Apache-2.0.

### Organization observed at those revisions

- **Plotters:** `plotters-backend` defines pixel, line, path, polygon, text, and
  image operations with backend-owned errors. `DrawingArea` adds a bounded
  region and coordinate translation. `ChartContext` adds axes, mesh, series,
  and annotations. Series lower to drawable elements; the line series collects
  input coordinates into owned storage. The SVG backend can target a string or
  file and serializes primitives directly.
- **Makie:** a `Figure` owns a scene, grid layout, content, and attributes. Axis
  blocks own sub-scenes, limits, ticks, labels, and interactions. Plots form a
  mutable tree with converted attributes and observable compute graphs. Scenes
  own plots, children, cameras, events, and backend screens. Backends implement
  screen construction and lifecycle rather than a tiny primitive renderer.
- **Vega-Lite:** a typed top-level spec composes unit, layer, facet, and concat
  specs. Compilation initializes configuration, normalizes shorthand, builds a
  model tree, parses mergeable data/scale/axis/legend/mark components,
  optimizes the dataflow, and assembles a lower-level Vega specification.
  Invalid values have explicit mark and scale-domain policies.
- **Matplotlib:** `Figure` tracks Axes and other Artists. Each `Axes` owns data
  limits, x/y axis objects, transforms, and ordered children such as `Line2D`.
  Artists draw themselves through a `RendererBase`; canvases bind figures to a
  concrete backend. The SVG renderer writes vector primitives directly and
  requires fixed metadata and ID salt for reproducible output.

## Sen's architectural boundary

Sen is a plotting semantics library, not a data analysis framework and not a
renderer. Its pipeline is:

```text
owned Figure / Axes / Series semantics
        -> validated view bounds, scales, ticks, and layout
                -> ordered renderer-neutral RenderPlan
                        -> deterministic SVG encoder
                        -> later Kagerou adapter
```

Every stage consumes validated values and produces an owned value. The SVG
encoder does not inspect scientific data or choose ticks. A future native
backend does not change how bounds, missing data, or scales work. Numeric
producers do not know that Sen exists.

The current renderer-neutral `PlotPoint`, `LineSeries`, `DataBounds`, and
`Figure` slice remains the foundation. New layers should be introduced through
reviewable roadmap issues rather than replaced by a scene graph.

## Figure, Axes, and Series model

### Figure

`Figure` is the owned root semantic value. During v0.1 it has one primary
two-dimensional `Axes`, created lazily when the first series is added or set
explicitly. Multi-panel grids, subfigures, shared axes, and inset axes are
deferred. This avoids exposing a general layout tree before a single plot is
correct.

The current `Figure.add_line(line)` remains the smallest path and delegates to
the primary Axes once that layer exists. Figure-level state is limited to size-
independent semantics such as title, primary Axes, and theme roles. Output size
is supplied to rendering so one semantic figure can be rendered at more than
one size.

`Figure` owns copies of inserted values. An accessor returns an owned copy,
never a live mutable reference into the figure. This matches the existing
line-series behavior and prevents changes to a caller's series or Axes from
silently invalidating a figure after insertion.

### Axes

`Axes` represents one rectangular two-dimensional plotting area, not one
individual x or y line. It owns:

- ordered series entries;
- x and y axis specifications;
- automatic or explicit view domains;
- labels, title, visibility, and legend policy;
- semantic style overrides that do not mention SVG or Kagerou.

Individual x/y axis specifications own scale kind, direction, optional domain
override, label, and tick policy. They do not own pixel coordinates. The
logical plot rectangle is assigned by layout.

Different series kinds remain concrete at the public boundary. Internally an
ordered tagged `SeriesEntry` may preserve insertion order across line and
scatter series, but Sen should not export type erasure, `Any`, or an open-ended
plot trait before Mojo has a clear safe representation. v0.1 needs only line
and scatter entries.

### Series

`LineSeries` owns ordered finite points and strictly increasing segment starts.
Each segment is a connected path. Bounds include every stored point and are
independent of segment topology. `ScatterSeries` later reuses the same finite
point and ownership rules but has no connectivity.

Series labels and style are semantic annotations. They do not store backend
paths, screen coordinates, generated tick values, layout boxes, or renderer
handles. Lowering may create optimized path batches, but those are derived
render-plan data and never mutate the source series.

## Data ownership and numeric-producer independence

Sen takes an owned snapshot at its public insertion boundaries:

- adding a line to Axes copies the line;
- setting Axes on a Figure copies the Axes;
- returned Figure/Axes/series values are independent copies;
- renderer and backend state never appears in semantic values.

The first API builds `LineSeries` from `PlotPoint` values. Later adapters may
accept Mojo-native lists, spans, iterators, or statically generic buffer views,
but must validate equal lengths and finite coordinates before ownership is
transferred or copied. They may not define a universal Sen array.

Sen must not import ShuhaFFT, Nami, Nagare, Nerai, dataframe packages, Python,
or a notebook runtime. A user can plot the output of any of them after adapting
it to finite numeric values. The rendering path performs no interpolation,
smoothing, fitting, resampling, decimation, or statistical aggregation unless
a later plot type documents that calculation as its own semantics.

Borrowed zero-copy series are deferred. Their lifetime and post-construction
mutation semantics are not worth weakening the deterministic v0.1 model.
Large-data benchmarks must demonstrate a material need before adding them.

## Missing and invalid data

Missing line data is topology, not a floating-point sentinel. The public rule
remains:

```text
finite points + explicit segment starts -> connected paths
```

`LineSeries.start_segment(point)` adds the first finite point after a gap.
Leading, repeated, and trailing gap markers are unrepresentable. NaN and
infinity remain invalid coordinates and never contribute to bounds, scales,
ticks, or rendering. Empty series have no bounds. Empty Axes use an explicit
default-domain policy rather than synthetic points.

This deliberately differs from Makie and Matplotlib, which use NaN in line
paths, and from Vega-Lite's configurable invalid-value modes. Their behavior
confirms that gap handling affects both marks and scale domains; Sen resolves
that ambiguity structurally before layout. No backend may reconnect distinct
segments or filter a point without reporting an upstream validation error.

Scatter adapters omit missing observations before construction rather than
storing a missing marker. Paired x/y adapters must apply one shared validity
decision to the pair; silently dropping only one coordinate would shift data.

## Scales and view bounds

`LinearScale` is a small pure mapping from one finite non-degenerate domain to
one finite non-degenerate logical range. It maps both endpoints exactly within
documented floating-point tolerance and extrapolates only when the caller asks
it to map a value outside the domain.

Source and destination endpoints may be increasing or decreasing. A reversed
source domain reverses axis direction intentionally; a decreasing destination
range implements the usual screen-space y direction. The constructor rejects
equal endpoints and non-finite values. `DataBounds` remains canonical with
minimum not exceeding maximum; axis reversal is a view choice, not corrupt
bounds.

View-domain resolution is separate from the scale:

1. union the finite bounds of visible series;
2. apply explicit per-axis overrides;
3. use a documented default domain for an empty Axes;
4. expand a constant automatic domain before constructing the scale;
5. validate the chosen domain for its scale kind.

For the first linear implementation, a constant value `v` expands symmetrically
by `abs(v) * 0.05`; when that is zero or underflows, the fallback half-width is
`0.5`. Explicit equal endpoints are rejected rather than silently expanded.
This distinguishes automatic presentation policy from a caller-specified
contract.

Only linear scales belong in v0.1. Logarithmic, symlog, categorical, temporal,
and unit-aware scales each require their own domain and tick contracts; a
generic function-valued scale would hide those invariants.

## Ticks

A tick locator consumes a validated domain and a positive target count and
returns owned finite tick values in visual order. A formatter converts those
values to deterministic labels without locale, environment, or backend state.

The linear locator should use human-readable steps drawn from a small declared
family such as `1`, `2`, `2.5`, `5`, and `10` times a power of ten. Tests fix
the tie-breaking, endpoint inclusion, reversed-domain order, negative-zero
canonicalization, and behavior for tiny and huge finite domains. The requested
count is a target, not a promise that permits duplicate ticks.

Tick location, label formatting, and tick rendering remain separate. Users may
later supply explicit values and labels, but v0.1 should not accept arbitrary
callbacks whose output cannot be validated or reproduced.

## Layout and lowering

Layout operates in finite logical output coordinates. It is deterministic for
the same semantic Figure, output size, and theme. The pipeline is:

1. validate the complete owned Figure snapshot;
2. resolve visible data bounds and axis domains;
3. locate and format candidate ticks;
4. estimate title, label, tick-label, and legend extents;
5. allocate figure, title, plot, x/y axis, and legend rectangles;
6. construct data-to-plot scales;
7. lower series, axes, grid, ticks, labels, clipping, and legend samples into an
   ordered `RenderPlan`.

v0.1 uses a documented deterministic text-extent estimate based on font size
and character count. It does not ask a renderer to measure host-installed
fonts, because that would make layout and snapshots backend- and machine-
dependent. The SVG specifies a fallback font family and positions text using
the same estimate. Accurate shaping is a later text subsystem contract, not a
reason to make the initial layout nondeterministic.

Layout failure is explicit when the requested finite positive output size
cannot contain the required boxes. It must not create negative rectangles,
NaN coordinates, or silently omit semantic content. Optional decorations can
have a documented priority order only after tests establish it.

## Render plan

`RenderPlan` is an internal owned value containing output size and a small
ordered command vocabulary. The initial commands are conceptually:

```text
fill rectangle
stroke line/path
draw markers
draw text
push rectangular clip
pop clip
```

Commands contain finite logical coordinates and fully resolved internal styles.
They contain no source data iterators, axis-domain logic, tick locators,
filesystem paths, SVG fragments, device handles, or Kagerou surfaces. Clip
stack balance and rectangle validity are checked when the plan is built and in
backend conformance tests.

The plan order is semantic: background, grid, clipped data marks, axes/spines,
ticks and labels, legend, then figure-level titles. Series preserve insertion
order within the data layer. A later z-order feature must be nominal and have a
stable tie-breaker rather than depend on hash or pointer order.

Render-plan types remain internal in v0.1. Exposing them would freeze a backend
ABI before the SVG reference implementation demonstrates the smallest useful
command set.

## Backend contract

The backend seam consumes a completed `RenderPlan`. It does not receive a
Figure. Conceptually, an internal backend supports:

```text
begin finite positive surface
emit resolved primitive commands in order
finish or return an error
```

A backend may optimize path batches or marker reuse, but it must preserve
command order, clipping, coordinates, styles, and text content. Backend failure
uses `raises`; a partially rendered output is never returned as successful.

Plotters shows the value of a small primitive trait and default fallbacks.
Matplotlib shows that renderer specialization can be useful for repeated paths.
Sen should adopt the seam but not let a backend generic parameter spread
through Figure, Axes, or Series types. Static dispatch can be introduced inside
the rendering module when there is a second backend.

Until then the SVG encoder is the one concrete consumer, and the internal trait
should not be exported. A fake recording backend in tests proves that lowering
does not depend on SVG serialization.

## SVG-first serialization

The first stable rendering entry point returns a complete SVG string:

```mojo
var svg = render_svg(figure, width=640, height=480)
```

Saving to a path is an explicit I/O helper layered on this string API. Semantic
Figure construction and render-plan creation perform no filesystem access.

The SVG encoder guarantees:

- UTF-8 XML with one declared namespace and finite positive `viewBox`;
- deterministic element and attribute order;
- locale-independent shortest documented numeric formatting;
- canonical zero instead of negative zero;
- XML escaping for text and attribute values;
- stable sequential IDs derived from render-plan order;
- balanced elements and clip references;
- no timestamp, random UUID, environment-derived metadata, host path, or
  compiler-specific object identity;
- identical bytes for identical validated input on every supported target.

Matplotlib's optional hash salt and date metadata demonstrate why
reproducibility must be the default, not a build configuration. Plotters'
string target demonstrates the useful in-memory boundary, but Sen separates
semantic lowering from encoding so future backends consume the same plan.

The encoder serializes only the subset it emits. It does not accept raw SVG,
CSS, scripts, event handlers, external URLs, or user-provided XML attributes in
v0.1. That keeps escaping and security review finite.

## Akari gate

Sen may depend on Akari only after Akari publishes and tests:

- one normalized finite color representation;
- explicit color-space and transfer-function semantics;
- deterministic interpolation and conversion;
- stable scientific palette values and licensing provenance;
- Mojo/compiler compatibility matching Sen's supported matrix.

Before that gate, Sen uses private semantic color roles and a small private
resolved sRGB representation solely for SVG. Neither becomes a public copied
color API. When Akari is adopted, the migration occurs at style resolution;
Figure/Axes/Series ownership, scales, layout, and render-plan ordering do not
change.

Sen does not absorb colormap generation, color management, or palette data.
Those remain Akari's responsibility.

## Kagerou gate

Kagerou is a post-v0.1 adapter. Work starts only when:

- Sen's render-plan command semantics and clipping pass the SVG golden suite;
- Kagerou's paths, transforms, strokes, fills, text decision, and surface
  lifetime are independently stable;
- the adapter can map commands without changing data, bounds, ticks, layout,
  color interpretation, or ownership;
- CPU/SVG-only consumers do not initialize a native or GPU renderer.

Kagerou types never enter the Figure, Axes, Series, Scale, Tick, or Layout APIs.
If Mojo packaging cannot express an optional dependency cleanly, the adapter
belongs in a separate integration package rather than forcing Kagerou on every
Sen installation.

## Errors and reachable mutation

All fallible public operations use `raises`. Invalid numeric values, corrupted
segment topology, mismatched adapter lengths, invalid domains, non-positive
output sizes, layout exhaustion, unbalanced internal clips, unsupported style
features, serialization failure, and backend resource failure are errors.

Mojo 1.0 underscore-prefixed fields remain externally reachable. Every public
operation that observes semantic storage revalidates the current topology and
numeric values before returning or lowering them. Validation occurs before
observable mutation where practical. Render-plan construction validates the
whole snapshot once; internal stages may then rely on that proof as long as
they do not expose a mutation boundary.

Counts that depend on topology, such as connected segment count, validate the
topology first. Raw storage counts may remain non-raising only when they neither
interpret nor expose invalid semantic state.

## Minimal Mojo API

The root stays concrete and small. The current foundation remains valid:

```mojo
from sen import Figure, LineSeries, PlotPoint

var line = LineSeries()
line.append(PlotPoint(0.0, 1.0))
line.start_segment(PlotPoint(2.0, 3.0))
var figure = Figure()
figure.add_line(line)
```

The intended v0.1 endpoint adds only the primary Axes configuration and SVG
entry point:

```mojo
from sen import Axes, Figure, LineSeries, PlotPoint, render_svg

var line = LineSeries()
line.append(PlotPoint(0.0, 1.0))
line.append(PlotPoint(1.0, 3.0))

var axes = Axes()
axes.set_x_label("time")
axes.set_y_label("value")
axes.add_line(line)

var figure = Figure()
figure.set_axes(axes)
var svg = render_svg(figure, width=640, height=480)
```

These are architectural target signatures, not implemented promises. API work
must confirm current Mojo ownership and keyword syntax. `LinearScale`, tick
locators, layout boxes, render plans, backend traits, SVG nodes, color storage,
and Kagerou adapters stay out of the root unless direct user need is proven.

No implicit global current Figure/Axes exists. No `plot(x, y)` overload is
added until two Mojo-native buffer adapters demonstrate a precise, non-copying
or explicitly copying contract without scientific-library dependencies.

## Adopted and rejected complexity

### Adopted

- From Plotters: coordinate translation is separate from data; a backend has a
  small fallible primitive boundary; owned series and in-memory SVG are useful.
- From Makie: Figure, Axes/layout, plot semantics, data limits, and backend
  screens are distinct concerns; layout must account for tick labels and
  legends before display.
- From Vega-Lite: semantic input is normalized before assembly; scales, axes,
  legends, marks, and layout are mergeable components; invalid-data policy must
  be explicit before marks and domains diverge.
- From Matplotlib: Figure owns Axes, Axes owns ordered artists/series and data
  transforms, rendering uses an abstract primitive interface, and clipping and
  repeated-path optimization belong below semantics.

### Rejected or deferred

- Plotters' backend generic parameters throughout chart types, immediate draw
  calls, shared interior-mutability backend, pixel-first layout, and broad
  element trait system are not Sen's public model.
- Makie's observable graph, mutable plot tree, global current Figure/Axes,
  scenes, cameras, interactions, recipes, dimensional conversions, GPU state,
  and backend screens are far beyond v0.1.
- Vega-Lite's JSON grammar, arbitrary field encodings, data transforms,
  selections, expression language, faceting compiler, and runtime signals are
  not required for a typed Mojo plotting library.
- Matplotlib's pyplot global state, mutation-heavy Artist hierarchy, dynamic
  subclass/plugin surface, NumPy dependency, NaN/masked path sentinels, and
  environment-dependent SVG metadata/IDs are rejected.
- Multi-panel layout, 3D, polar coordinates, interactive navigation, animation,
  arbitrary user drawing commands, custom SVG injection, notebook display,
  and renderer-managed data reduction remain deferred.

## Test and snapshot strategy

### Semantic unit tests

- finite points, bounds, owned copies, empty series, explicit segments, and
  externally corrupted storage;
- line/scatter insertion order and Figure/Axes copy independence;
- empty, constant, positive, negative, reversed, tiny, and huge linear domains;
- scale endpoints, monotonicity, extrapolation, and round trips;
- deterministic tick values, label formatting, target-count edge cases, and
  negative-zero elimination;
- automatic bounds union, explicit overrides, hidden series, and constant-data
  expansion.

### Layout and render-plan tests

- exact boxes for compact fixed-size figures;
- finite, non-negative, non-overlapping required rectangles;
- stable command order and balanced clip stack;
- one path per explicit line segment, never across a gap;
- all data commands clipped to the plot rectangle while axes/labels remain
  outside that clip;
- a fake recording backend receives the same command stream as SVG encoding;
- corrupted reachable semantic state fails before the first backend command.

### SVG snapshots

Golden fixtures are intentionally small and reviewed as text. They cover an
empty Axes, singleton/constant data, a segmented line, multiple series, reversed
axes, tick labels, legend, clipping, and Unicode/XML-special labels. Tests
assert exact bytes plus focused escaping, numeric-format, attribute-order, ID,
and no-timestamp properties.

Snapshot updates include the command that generated them and a semantic reason
for the change. A formatter or platform upgrade may not rewrite every fixture
without explaining whether the public deterministic-output contract changed.

The installed-package smoke test imports only root API and creates an in-memory
SVG. It does not write a file or depend on a desktop session.

## Benchmark strategy

Benchmarks separate:

- series construction/copy and bounds aggregation;
- view-domain, tick, and layout computation;
- semantic lowering to a render plan;
- SVG encoding from an existing plan;
- complete `render_svg` latency and output bytes.

Datasets include empty, 1, 10, 1,000, 100,000, and later 1,000,000 points;
single and many short segments; one and many series; short and Unicode-heavy
labels; and sizes around tick/layout decisions. Measure warm and cold calls,
allocations when Mojo tooling supports them, and output size. Correctness runs
outside the timed region.

Every report records Sen commit, Mojo version/compiler options, CPU, OS, data
shape/provenance, output size, warmup, iterations, and statistic. Renderer
comparisons must normalize feature sets and output semantics. Benchmark results
are development evidence, not permanent marketing claims.

Decimation is not a benchmark shortcut. It requires a separately documented
visual-error policy and remains outside v0.1.

## Dependency-ordered issue sequence

The executable roadmap remains authoritative. The reference evidence confirms
this order and adds explicit exit criteria:

1. **S1.1 Linear scale.** Finalize finite, reversed, degenerate, and endpoint
   contracts with reference/property tests; no Axes or renderer dependency.
2. **S1.2 Axis/Axes model.** Add x/y semantic specifications and primary-Axes
   Figure ownership while preserving `Figure.add_line` and owned copies.
3. **S1.3 Linear ticks.** Implement deterministic location/formatting across
   signs and magnitudes; freeze tie-break fixtures.
4. **S1.4 View bounds.** Union visible series, apply overrides, and expand only
   automatic constant domains.
5. **S2.1 Line style.** Add private resolved color roles and finite stroke/dash
   semantics without SVG, Akari, or Kagerou types.
6. **S2.2 Scatter series.** Reuse point/bounds ownership; establish an internal
   ordered series entry without exporting type erasure.
7. **S2.3 Figure layout.** Produce exact backend-neutral logical boxes with a
   deterministic text estimate and explicit insufficient-space errors.
8. **S2.4 Legend entries.** Derive stable label/sample semantics from visible
   ordered series.
9. **S3.1 Render plan and backend conformance.** Lower validated figures to the
   minimal ordered command set; add a recording backend and clip invariants.
10. **S3.2 SVG encoder.** Serialize every required command with fixed escaping,
    numeric, ordering, ID, and metadata rules.
11. **S3.3 SVG string API.** Export only the stable root rendering entry point;
    keep file I/O separate.
12. **S3.4 Golden fixtures.** Lock exact compact documents across the supported
    platform matrix.
13. **S4.1 Root audit.** Remove leaked implementation types and document every
    public error/ownership contract.
14. **S4.2 Numeric-buffer proof.** Demonstrate two Mojo-native adapters without
    a Sen array or numeric-producer dependency.
15. **S4.3 Package matrix.** Require installed-root SVG smoke and deterministic
    goldens on macOS ARM64, Linux x86-64, and Linux ARM64.
16. **Evaluate Akari.** Pin only after its color gate passes; migrate private
    style resolution without changing plot semantics.
17. **Evaluate Kagerou post-v0.1.** Add an isolated adapter only after both
    render-plan and surface APIs stabilize.

No issue may combine a semantic layer with its renderer merely to produce an
early screenshot. SVG is the proof that the layers compose, not the source of
their contracts.
