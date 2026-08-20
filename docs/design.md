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

## Out of scope

Signal processing, interpolation, optimization, dataframes, native windowing, and a bundled low-level renderer are outside the core plotting package.
