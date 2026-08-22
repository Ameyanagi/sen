# Architecture

Sen owns Figures, axes, series, scales, ticks, legends, themes, plot semantics, layout, and rendering backend contracts.

## Dependency boundary

Allowed ecosystem dependencies: Akari for color; SVG is the initial backend. A Kagerou adapter is introduced only after both APIs stabilize.
Expected downstream consumers: Scientific programs and notebooks that need plots without depending on how their numeric data was produced.

Dependencies point from applications and higher-level packages toward smaller
foundations. This repository must never import a downstream consumer. New
dependencies require a documented need and must not force unrelated users to
install an application, renderer, language layer, or scientific stack.

## Layers

The semantic layer owns figures, axes, series, scales, ticks, legends, and
themes. The package-root `build_render_plan` API produces a validated
`RenderPlan`: ordered device-space commands with no file I/O and no SVG syntax.
`CommandKind`, `PlanPoint`, `DrawCommand`, and `RenderPlan` are the small
supported contract for another backend. Points, commands, and plans validate at
public construction; command kinds come from the closed named constants.
Kind-specific validation mirrors the backend contract: rectangle extents are
nonnegative, data primitives have series indices, markers have palette slots,
and styled line, rectangle, and area commands have the geometry and style data
their encoders consume. All four values are equatable, and `validate()` is an
explicit checkpoint after unusual direct storage mutation. The SVG adapter
consumes exactly that public plan and owns only byte encoding, escaping, and
saving. Line, scatter, area, histogram, and error-bar semantics therefore do
not depend on the output backend.

Planned later areas include heatmaps, contours, and additional backends.

The package root exports only the small documented public surface. Algorithms,
generated tables, platform details, and backend implementations remain in
their owning modules. Generic Mojo-native buffers, spans, strings, and
collections are preferred over an ecosystem-specific universal container.

## Data flow

Input validation occurs at the public boundary. Internal layers operate on
explicit typed values, produce deterministic outputs for deterministic inputs,
and report invalid state rather than silently replacing it with a default.
I/O, clocks, randomness, terminal queries, filesystem access, and accelerator
selection stay at explicit effect or backend boundaries.

Figure lowering constructs each axis scale once and performs scalar maps while
preserving command and segment order. Affine interpolation forms the unitless
input fraction before multiplying by the output span, and halves opposite-sign
extreme endpoints before subtraction when their direct span would overflow.
Lowering rejects any genuinely unrepresentable extrapolated coordinate before
it can enter a plan. `LinearScale.map_all` uses the same stable arithmetic with
native-width SIMD for callers that already have one regular affine buffer
kernel; its standalone microbenchmark is not reported as a render phase.
Variable-length decimal encoding and XML assembly remain scalar because
profiling identifies formatting and buffer writes—not coordinate arithmetic—as
the dominant SVG cost.

Mojo 1.0 does not make underscore-prefixed struct fields private. Direct
mutation of that storage is out of contract. Constructors establish semantic
invariants, mutators validate their inputs and the local invariants they affect,
and read-only operations trust stored state without revalidation. Each validated
type exposes one explicit `validate() raises` checkpoint for unusual low-level
mutation.
