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

- Revalidate reachable mutable numeric storage and require finite ordered bounds.
- Revalidate externally reachable segment topology before reporting its count.
- Harden the planned rendering boundary around six generic primitives,
  deterministic text/SVG contracts, bounded ticks, and versioned future backend
  integration.
