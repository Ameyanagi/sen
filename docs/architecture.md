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

Planned implementation areas: figure, axes, series, scales, ticks, legends, themes, line/scatter/histogram/errorbar/heatmap/contour plots, and SVG backends.

The package root exports only the small documented public surface. Algorithms,
generated tables, platform details, and backend implementations remain in
their owning modules. Generic Mojo-native buffers, spans, strings, and
collections are preferred over an ecosystem-specific universal container.

The [reference architecture](reference-architecture.md) records the exact
primary plotting sources used to evaluate Figure/Axes/Series ownership,
layout, render-plan, SVG, and future backend seams. It is design evidence only;
no reference implementation is a runtime or source dependency.

## Data flow

Input validation occurs at the public boundary. Internal layers operate on
explicit typed values, produce deterministic outputs for deterministic inputs,
and report invalid state rather than silently replacing it with a default.
I/O, clocks, randomness, terminal queries, filesystem access, and accelerator
selection stay at explicit effect or backend boundaries.

Mojo 1.0 does not make underscore-prefixed struct fields private. Constructors
validate semantic values, and every public accessor or operation that observes
numeric content revalidates reachable storage. Collection counts and emptiness
may remain non-raising because they do not expose or compute from numeric state.
