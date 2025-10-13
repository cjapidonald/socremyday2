#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
BUILD_DIR="$ROOT_DIR/Build"
DERIVED_DATA_DIR="$HOME/Library/Developer/Xcode/DerivedData"

if [ -d "$BUILD_DIR" ]; then
  find "$BUILD_DIR" -name "build.db" -delete
  echo "Removed cached build databases under $BUILD_DIR"

  # Remove any stale XCBuildData folders that can corrupt incremental builds
  find "$BUILD_DIR" -name "XCBuildData" -type d -prune -exec rm -rf {} +
  echo "Removed XCBuildData directories"
else
  echo "No Build directory found at $BUILD_DIR"
fi

if [ -d "$DERIVED_DATA_DIR" ]; then
  # Clear out derived data folders created for this project to avoid stale caches
  # causing the "no more rows available" build database error when Xcode reuses
  # corrupt incremental build state.
  FOUND_DIRS=$(find "$DERIVED_DATA_DIR" -maxdepth 1 -type d -name "scoremyday2-*" -print)
  if [ -n "$FOUND_DIRS" ]; then
    # shellcheck disable=SC2086
    rm -rf $FOUND_DIRS
    echo "Removed project derived data from $DERIVED_DATA_DIR"
  else
    echo "No project-specific derived data directories found under $DERIVED_DATA_DIR"
  fi
else
  echo "Derived data directory $DERIVED_DATA_DIR does not exist; nothing to clean"
fi
