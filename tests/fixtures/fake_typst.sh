#!/bin/sh
set -eu

if [ "$#" -lt 3 ] || [ "$1" != "compile" ]; then
  echo "fake Typst received an invalid invocation" >&2
  exit 64
fi

source_path=$2
output_path=$3
if grep -q 'SEN_TYPST_FAIL' "$source_path"; then
  echo "synthetic Typst diagnostic" >&2
  exit 7
fi
if grep -q 'SEN_TYPST_SLEEP' "$source_path"; then
  sleep 3
fi

printf '%s\n' '<svg viewBox="0 0 72 14" width="72pt" height="14pt" xmlns="http://www.w3.org/2000/svg"><path id="sen-fake-typst" d="M0 0h1v1z"/></svg>' > "$output_path"
