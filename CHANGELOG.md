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
