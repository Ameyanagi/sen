# Changelog

This project follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and uses semantic versioning.

## [Unreleased]

### Added

- Explicit text-metrics providers and an optional published-Kumihan adapter for
  measured titles, tick collision selection, and legends.
- Author-written accessible descriptions on Plot, Figure, and RenderPlan.
- Render-scoped bounded Typst fragment reuse with placement-specific SVG IDs.
- Three-platform isolated consumer checks against the published 0.1.0 README.

- Consuming `Plot.with_*` methods for fluent, ownership-preserving construction
  across every existing plot overload and configuration call, while retaining
  all mutable mutators.
- `Plot.figure()`, `into_figure()`, `validate()`, and direct
  `build_render_plan()` bridges, plus explicit-margin `Plot.save_svg()`.
- Symmetric explicit x/y ticks, automatic-limit restoration, and matching
  mutable and fluent `Plot` controls.
- Public `encode_svg(plan)` and `write_svg(path, svg)` prepared-output APIs;
  `save_svg(path, svg)` remains a compatibility alias.
- Symmetric in-memory and explicit-margin render/save methods on `Figure`.
- Independent physical figure size and raster DPI configuration, including
  fluent inch- and pixel-based sizing.
- Light and dark themes with configurable CJK-capable typography.
- Point-based marker sizing, opacity, line caps, and line joins on
  `SeriesStyle`.
- CJK/emoji-aware deterministic text metrics, adaptive margins, dense tick
  label selection, word-aware long-title fitting, and lowest-overlap automatic
  legends.
- Explicit Japanese, Simplified Chinese, Traditional Chinese, and Korean text
  locales with language-correct fallback ordering and SVG language metadata.
- Optional bounded Typst vector math for titles and axis labels through
  `Text.typst_math(...)` and `TypstOptions`; ordinary text remains
  subprocess-free.

### Changed

- Keep the README consumer quickstart compatible with immutable 0.1.0; document
  unreleased fluent/theme/font APIs separately. Workspace and recipe remain at
  0.1.0 until a coordinated new release; existing package bytes are untouched.

- Validate public nominal discriminators at explicit checkpoints and reject
  configuration fallthrough at render time without rescanning point data.
- Report complete advanced-series index ranges and empty-figure guidance.
- Count empty area and rectangle series in figure bounds diagnostics, and let
  ownership-taking area/rectangle insertion retain legend labels.
- Emit physical SVG dimensions with a stable DPI-independent logical view box,
  and clip series through an identifier-free nested SVG viewport.
- Increase automatic view padding so physical markers and strokes at extrema
  remain visible.
- No-argument rendering now uses the figure's stored physical size. Legacy
  logical-coordinate rendering remains available when both width and height are
  supplied; the former one-sided width/height default calls are no longer
  supported.

## [0.1.0] - 2026-08-22

### Added

- Renderer-neutral figures, validated line/scatter/area/rectangle series, data
  bounds, explicit missing-data topology, styles, axes, and layout semantics.
- A concise `Plot` front door for lines, scatter, segmented areas, steps, stems,
  symmetric error bars, numeric and categorical bars, and histograms.
- Linear and base-10 logarithmic scales, stable tick location, explicit limits,
  labels, grids, legends, and deterministic automatic or custom colors.
- Deterministic SVG rendering with semantic CSS classes, XML escaping, clipping,
  stable formatting, in-memory rendering, and one-call file output.
- Public validated render-plan values for renderer-independent integrations.
- List and aliased-span ingestion without staging copies, plus SIMD batch scale
  mapping and histogram validation/reduction on supported native targets.
- Golden SVG fixtures, README compile checks, installed-package smoke tests, and
  reproducible render-pipeline benchmarks and profiling guidance.

### Changed

- Validate series invariants at construction and mutation, trust them on reads,
  and provide explicit `validate()` checkpoints for unusual low-level mutation.
- Make `LineSeries.bounds()` return `DataBounds` directly and reject empty series.
- Compute line-series bounds in one pass without constructing intermediate
  validated bounds values.
- Use structure-of-arrays series storage and ownership-taking insertion to avoid
  point staging and redundant copies.
- Give every fallible public operation value-specific validation errors and
  actionable remediation guidance.

[Unreleased]: https://github.com/Ameyanagi/sen/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Ameyanagi/sen/releases/tag/v0.1.0
