# Changelog

This project follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and uses semantic versioning after the first public release.

## [Unreleased]

### Added

- Initial experimental repository scaffold.
- Renderer-neutral plot points, line series, data bounds, and figures.
- Explicit line segments as the nominal missing-data policy, without NaN
  sentinels or renderer dependencies.

### Changed

- Validate series invariants at construction and mutation, trust them on reads,
  and provide explicit `validate()` checkpoints for unusual low-level mutation.
- Make `LineSeries.bounds()` return `DataBounds` directly and reject empty series.
- Compute line-series bounds in one pass without constructing intermediate
  validated bounds values.
