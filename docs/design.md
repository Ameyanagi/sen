# Design

## Principles

- Mojo is the runtime implementation language.
- Prefer pure Mojo and safe standard-library APIs.
- Keep the root API small, typed, documented, and testable.
- Separate semantic contracts from optimized CPU, SIMD, GPU, terminal, or
  rendering backends.
- Establish correctness and reference fixtures before optimization.
- Make invalid public configuration unrepresentable when practical; otherwise
  reject it explicitly.
- Preserve source mappings, numerical tolerances, ownership, and provenance as
  first-class data when the domain requires them.
- Do not add a framework-wide array, executor, renderer, or application model.

## Tradeoffs

The project accepts a narrower initial feature set in exchange for reviewable
contracts and sparse dependencies. Generated tables are acceptable when their
sources, Unicode or data version, licenses, checksums, and deterministic update
procedure are committed. Consumers must not need the generator toolchain.

Validated semantic values establish their invariants at construction. Mutators
validate new inputs and only the local invariant they change; read-only methods
trust stored state and stay non-raising unless the operation has a genuine
failure case. Direct mutation of underscore-prefixed storage is out of contract,
with one public `validate()` checkpoint per validated type for unusual low-level
use.

`Figure.add_line()` takes ownership of a constructed `LineSeries` and moves it
into ordered figure storage without copying or revalidating it. The figure trusts
the series' construction-time invariants; `Figure.validate()` remains the explicit
checkpoint after unusual low-level mutation.

## Missing data

Line gaps are topology, not numeric coordinates. `LineSeries.start_segment()`
attaches the first finite point after a gap to a new connected segment. This
makes leading, repeated, and trailing gap markers unrepresentable, preserves
the global order of valid observations, and keeps missing samples out of data
bounds. NaN remains invalid rather than acquiring context-dependent meaning.

`LineSeries` stores coordinates in parallel `Float64` buffers while preserving
`PlotPoint` at the pointwise API boundary. `from_xy()` is the bulk fast path,
validating borrowed coordinate spans while filling owned buffers in one pass;
`append_all()` validates a complete batch before mutation. Bulk reads such as
bounds operate directly on the coordinate buffers.

Step, stem, and symmetric error-bar entry points lower to a single validated
`LineSeries` per call. Disconnected stems, error bars, and caps use explicit
segment starts, keeping one logical insertion slot and label without teaching
renderers new line topology. Their destination buffers reserve the exact final
size and are filled directly.

Filled bars and histograms share `RectangleSeries`, a backend-neutral
axis-aligned patch primitive with structure-of-arrays edge storage. One
rectangle series may contain many bars while retaining one order entry, style,
and label. Categorical bars store explicit x tick positions and labels on the
figure; the renderer consumes that axis state without owning category
semantics. Equal-width histogram construction validates and reduces finite data
in native SIMD chunks, then performs one scalar scatter-count pass because bin
destinations are data-dependent. It is linear in samples plus bins and never
sorts or copies the input span.

Filled areas share `LineSeries`' explicit segment topology and add one finite
constant baseline. Each segment lowers to a closed device-space polygon, so
rendering backends do not need to reinterpret missing values or repeat bounds
and axis transformation rules.

## Deterministic SVG reference backend

`render_svg` calls the same package-root `build_render_plan` API available to
other backends, then a hand-written encoder emits the complete document.
Commands are ordered as background, plot frame, optional x then y grid lines, x
axis followed by each tick/label pair, y axis followed by each tick/label pair,
title/x-title/y-title when present, series primitives in figure insertion order,
then the legend background and each labeled row's glyph/text pair in that same
insertion order. The SVG adapter places the contiguous series block in a nested
SVG viewport. This clips series without a document-global identifier.
Plain-text figures can therefore be embedded together directly; figures
containing Typst fragments use the caller-supplied `TypstOptions` ID prefix
described below. Attributes are fixed left to right: the root uses `xmlns`,
`role`, optional `lang`/`xml:lang`, `width`, `height`, `viewBox`; rectangles use
`x`, `y`, `width`, `height`, `fill`, followed when present by `stroke`,
`stroke-width`; lines use `x1`, `y1`, `x2`, `y2`, `stroke`, `stroke-width`;
text uses `x`, `y`, `fill`, `font-family`, `font-size`, `text-anchor`; and
polylines use `points`, `fill`, `stroke`, `stroke-width`. Area polygons
additionally use a fixed fill opacity.
Filled data rectangles and areas use the same insertion-indexed semantic
classes as other series. An area legend glyph preserves its polygon's color,
opacity, outline width, cap, join, and dash style.

The configured renderer stores physical width and height in inches, uses a
stable 100-logical-unit-per-inch view box, and keeps export DPI separate. Thus
changing only DPI leaves SVG bytes and layout unchanged while changing future
raster dimensions. Point-based typography, line widths, and marker diameters
are converted once to logical units. Legacy explicit width/height overloads
continue to accept logical coordinates.

Layout starts from deterministic CJK/emoji-aware fallback text metrics rather
than host font discovery. The renderer expands the minimum margins for actual
tick, title, axis-label, and legend extents; fits an overlong title at word or
grapheme boundaries; emits every tick/grid mark while greedily selecting
non-overlapping labels; and places an automatic legend in the lowest-overlap
plot corner. Rendering remains deterministic across hosts.

An explicit CJK locale selects a language-specific Japanese, Simplified
Chinese, Traditional Chinese, or Korean fallback order and is copied to SVG
`lang` and `xml:lang`. Locale-neutral `AUTO` remains available when content is
mixed or unknown. The fallback metrics cover modern CJK ranges through Unicode
17 Extension J, combining sequences, emoji ZWJ sequences, flags, and keycaps.

Plain text is encoded directly and never starts a process. `Text.typst_math`
is an explicit trusted-markup boundary: only marked title or axis-label roles
invoke a local Typst compiler, and the resulting vector fragment is embedded in
the role's nested SVG viewport. Sen quotes every dynamic shell argument,
isolates compilation in a fresh temporary root, enforces source/output limits
and a wall timeout, captures bounded diagnostics, prefixes generated SVG IDs by
caller namespace, role, and command index, and raises after temporary cleanup.
Callers inlining several complete Typst-enabled figures assign each one a
distinct validated `TypstOptions` prefix. This is native Typst markup, not a
LaTeX parser or compatibility claim.

SVG geometry uses fixed decimal notation with at most three fractional digits.
Values round half away from zero; trailing fractional zeros and a trailing point
are removed; rounded negative zero is `0`; exponent notation is never used.
Tick-label precision follows the tick step: ordinary steps use the number of
decimal places needed to bring the step to at least one, while steps below
`0.001`, steps at least `1e12`, or tick values at least `1e12` use normalized
scientific notation with a three-decimal mantissa. XML text escapes `&`, `<`,
`>`, `"`, and `'`.

A constant x or y domain is padded on both sides by the larger of `0.5` and five
percent of the constant's magnitude. If that interval cannot be represented as
two distinct finite `Float64` values, rendering raises. Figures with no points
also raise. Each connected line segment becomes one SVG `polyline`, preserving
explicit gaps.

Nonconstant automatic view bounds start with eight-percent padding, then expand
further when required by the actual point-sized marker or stroke radius and the
measured plot length. Explicit axis limits remain exact and intentionally clip
geometry outside those limits.

The renderer returns a `String` ending in exactly one newline after `</svg>`.
`save_svg` is the separate I/O boundary; it creates missing parent directories
and writes the supplied bytes unchanged.
Regenerate the committed golden files from the real renderer with:

```sh
pixi run regen-fixtures
```

Review the resulting fixture diff and run `pixi run check`; fixture bytes should
never be edited independently of the renderer.

## Out of scope

Signal processing, interpolation, optimization, dataframes, native windowing, and a bundled low-level renderer are outside the core plotting package.


### Font metrics, descriptions, and optional compilation

Layout accepts an explicit `TextMetrics` provider at the prepared-plan boundary.
Default fallback metrics remain deterministic and dependency-free. Providers
validate the selected font family/weight, measure complete runs, and supply
line boxes plus explicit baseline extents; additive providers retain linear prefix measurements.
The optional `sen_kumihan` source module reads installed, pinned Kumihan APIs;
it never imports sibling source trees or performs host font discovery.

Author-written accessible descriptions survive Plot/Figure/RenderPlan lowering.
SVG validates and escapes their XML scalars without inventing conclusions.
Typst reuse is local to one encoding, keyed by all compiler inputs and options,
bounded in entry count and bytes, and precedes placement-specific ID rewriting.
