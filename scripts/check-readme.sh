#!/usr/bin/env bash
set -euo pipefail

readme_mode=source
if [[ "${1:-}" == --installed ]]; then
  readme_mode=installed
  shift
fi
readme_source=${1:-README.md}
readme_import_args=()
if [[ "$readme_mode" == source ]]; then
  readme_import_args=(-I "$PWD/src")
fi

readme_compile_dir=$(mktemp -d "${TMPDIR:-/tmp}/sen-readme.XXXXXX")
cleanup() {
  if [[ -n "${readme_compile_dir:-}" && -d "$readme_compile_dir" ]]; then
    rm -rf -- "$readme_compile_dir"
  fi
}
trap cleanup EXIT

awk -v output_dir="$readme_compile_dir" '
  BEGIN {
    fence = ""
    block = 0
  }

  fence == "" {
    if ($0 ~ /^```mojo[[:space:]]*$/) {
      block++
      output_file = sprintf("%s/%03d.mojo", output_dir, block)
      printf "%s", "" > output_file
      close(output_file)
      fence = "mojo"
      next
    }
    if ($0 ~ /^```/) {
      fence = "other"
      next
    }
    next
  }

  $0 ~ /^```[[:space:]]*$/ {
    if (fence == "mojo") {
      close(output_file)
    }
    fence = ""
    next
  }

  fence == "mojo" {
    print > output_file
  }

  END {
    if (fence != "") {
      print "README.md contains an unclosed fenced code block." > "/dev/stderr"
      exit 1
    }
  }
' "$readme_source"

shopt -s nullglob
readme_blocks=("$readme_compile_dir"/*.mojo)
if (( ${#readme_blocks[@]} == 0 )); then
  printf 'README.md contains no Mojo fenced blocks.\n' >&2
  exit 1
fi

for block_file in "${readme_blocks[@]}"; do
  block_name=$(basename "${block_file%.mojo}")
  if ! (cd "$readme_compile_dir" && mojo build ${readme_import_args[@]+"${readme_import_args[@]}"} "$block_file" -o "$readme_compile_dir/$block_name"); then
    printf 'README Mojo block %d failed to compile.\n' "$((10#$block_name))" >&2
    exit 1
  fi
  if [[ "$readme_mode" == installed ]]; then
    (cd "$readme_compile_dir" && "./$block_name")
  fi
done

printf 'README compile check passed: %d Mojo block(s).\n' "${#readme_blocks[@]}"
