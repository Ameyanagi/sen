#!/usr/bin/env bash
set -euo pipefail

sen_package_version=$(sed -n 's/^version = "\([^"]*\)"$/\1/p' pixi.toml)
if [[ -z "$sen_package_version" ]]; then
  printf 'pixi.toml must declare the package version.\n' >&2
  exit 1
fi

# The first channel has strict priority: require the package just built locally.
# Both imports resolve through the consumer environment; no source -I is added.
pixi exec \
  --channel "$PWD/output" \
  --channel https://ameyanagi.github.io/mojo-channel \
  --channel https://conda.modular.com/max \
  --channel conda-forge \
  --spec 'mojo==1.0.0' --spec "mojo-sen==$sen_package_version" \
  --spec 'mojo-kumihan==0.1.0' \
  -- mojo run fonts/test_kumihan_metrics.mojo
