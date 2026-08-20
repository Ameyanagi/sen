# Roadmap

Each checkbox is one reviewable issue with code, focused tests, and documentation.
Milestones advance only through the explicit gates below; the semantic model
must remain usable without any renderer.

Routine `pixi run check` covers formatting, tests, and `.mojoc` precompilation.
`pixi run package` builds and tests the installed artifact separately as a
manual/release gate; it is not part of the routine CI task until S4.3 lands.

## v0.1 — Foundation

### S0 — Renderer-neutral series model

- [x] **S0.1 Finite data points:** validate construction and revalidate public
  observation after reachable Mojo 1.0 storage mutation.
- [x] **S0.2 Line-series bounds:** preserve point order, validate finite ordered
  `DataBounds`, and reject mutated nonfinite/reversed state before observation.
- [x] **S0.3 Figure seed:** own an ordered collection of line series without
  backend, color, filesystem, or scientific-algorithm dependencies.
- [ ] **S0.4 Missing-data policy:** decide whether gaps use segmented series,
  optional points, or another nominal representation before accepting NaN.

Completion gate: `from sen import Figure, LineSeries, PlotPoint` compiles from
the installed package; empty state and bounds behavior have invariant tests.

### S1 — Axes and scales

- [ ] **S1.1 Linear scale:** map a validated data domain to a finite output
  range, with explicit reversed-domain and degenerate-domain behavior.
- [ ] **S1.2 Axis model:** define orientation, domain, label, and scale ownership
  without pixel, SVG, or Kagerou types.
- [ ] **S1.3 Tick locator:** generate deterministic human-readable linear ticks
  for positive, negative, tiny, and large domains.
- [ ] **S1.4 View bounds:** combine visible series extents and explicit axis
  overrides, with reference fixtures for empty and constant data.

Dependency gate: S1 starts after S0.4 fixes missing-data semantics. Its tests
must use only Mojo standard-library values.

### S2 — Plot semantics and layout

- [ ] **S2.1 Line style:** add semantic stroke width, dash, marker, and color
  roles without importing backend geometry.
- [ ] **S2.2 Scatter series:** add marker-only series sharing the S0 data and
  missing-data contracts.
- [ ] **S2.3 Figure layout:** compute title, plot-area, axes, and legend boxes in
  backend-independent logical coordinates.
- [ ] **S2.4 Legend entries:** derive stable labels and samples from visible
  series without rendering them.

Akari gate: pin Akari only after its normalized color value and interpolation
contract passes Akari's release gate. Until then, Sen uses an internal semantic
color role or defers configurable colors; no copied color type becomes public.

### S3 — Deterministic SVG backend

- [ ] **S3.1 Render plan:** lower a figure into a small ordered drawing-command
  model that contains no file I/O.
- [ ] **S3.2 SVG encoding:** encode lines, markers, axes, tick labels, clipping,
  and legends with deterministic attribute ordering and numeric formatting.
- [ ] **S3.3 String API:** return complete SVG as a `String`; keep saving to a
  path in an explicit I/O helper.
- [ ] **S3.4 Golden fixtures:** snapshot compact plots and separately test XML
  escaping, coordinate transforms, and deterministic output.

Dependency gate: SVG starts only after S1 and S2 contracts stabilize. SVG does
not require Kagerou and remains the portable reference backend.

### S4 — Release hardening

- [ ] **S4.1 Root audit:** export only stable semantic values and the SVG entry
  point; keep layout and encoder implementation types internal.
- [ ] **S4.2 Numeric-buffer proof:** demonstrate adapters from at least two
  Mojo-native collection/span shapes without defining a universal Sen array.
- [ ] **S4.3 Package matrix:** build and smoke-test the precompiled package and
  run deterministic SVG fixtures on every supported target.

Kagerou gate: a native backend is a post-v0.1 adapter. It starts only after
Sen's render plan and Kagerou's geometry/surface APIs are independently stable;
neither project changes its core semantic model merely to fit the other.

## v0.2 — Usability

- Add histogram and error-bar semantics after line/scatter usage validates the
  series model.
- Add ergonomic builders only for repeated friction demonstrated by examples.
- Submit a modular-community recipe when SVG plotting is useful by itself.

## v0.3 — Performance

- Add reproducible large-series layout and SVG-encoding benchmarks.
- Introduce decimation only with explicit visual-error contracts.
- Optimize measured bottlenecks without coupling plot semantics to a backend.

## v1.0 — Stability

- Document every public symbol, error, numeric tolerance, and output guarantee.
- Publish compatibility and deprecation policies across the CI platform matrix.
- Require downstream proof from a scientific program that does not depend on
  how Sen's input values were produced.

## Test matrix

- **Unit:** validation, empty/singleton series, bounds, scales, ticks, and layout.
- **Reference value:** known transforms, tick sequences, and compact SVG output.
- **Invariant:** finite bounds, endpoint-preserving scales, stable series order,
  backend-independent layout, and deterministic encoding.
- **Packaging:** installed root imports and a minimal in-memory SVG render.

## Not planned

Signal processing, interpolation, optimization, dataframes, notebooks, native
window management, GUI interaction, a bundled low-level renderer, and Kagerou
integration are outside v0.1.
