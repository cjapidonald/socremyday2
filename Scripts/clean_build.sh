#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
BUILD_DIR="$ROOT_DIR/Build"

if [ ! -d "$BUILD_DIR" ]; then
  echo "No Build directory found at $BUILD_DIR"
  exit 0
fi

find "$BUILD_DIR" -name "build.db" -delete
echo "Removed cached build databases under $BUILD_DIR"

# Remove any stale XCBuildData folders that can corrupt incremental builds
find "$BUILD_DIR" -name "XCBuildData" -type d -prune -exec rm -rf {} +
echo "Removed XCBuildData directories"
