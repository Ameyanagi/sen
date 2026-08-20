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

## Missing data

Line gaps are topology, not numeric coordinates. `LineSeries.start_segment()`
attaches the first finite point after a gap to a new connected segment. This
makes leading, repeated, and trailing gap markers unrepresentable, preserves
the global order of valid observations, and keeps missing samples out of data
bounds. NaN remains invalid rather than acquiring context-dependent meaning.

## Out of scope

Signal processing, interpolation, optimization, dataframes, native windowing, and a bundled low-level renderer are outside the core plotting package.
