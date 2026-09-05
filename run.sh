#!/bin/bash
# Quick dev loop: compiles a debug build and runs it directly (no .app bundle,
# no codesigning). Use build.sh to produce the real DiskCleaner.app.
set -euo pipefail
cd "$(dirname "$0")"

SOURCES=$(find Sources/DiskCleaner -name '*.swift')
BIN="/tmp/diskcleaner-dev"

echo "Compiling (debug)..."
# shellcheck disable=SC2086
swiftc -parse-as-library $SOURCES -o "$BIN"

echo "Running..."
"$BIN"
