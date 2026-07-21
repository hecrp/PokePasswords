#!/bin/bash
# Setup script for Pokepasswords
# Fetches Zig package dependencies (zigimg) into zig-pkg/

set -euo pipefail

if ! command -v zig >/dev/null 2>&1; then
    echo "Error: Zig is not installed."
    echo "Install Zig 0.16.0 or newer from https://ziglang.org/download/"
    exit 1
fi

ZIG_VERSION=$(zig version)
echo "Using Zig ${ZIG_VERSION}"
echo "Fetching package dependencies..."

zig build --fetch

echo ""
echo "Setup completed successfully!"
echo "Build with:  zig build"
echo "Test with:   zig build test"
echo "Run with:    zig build run -- --sprite sprites/pokemon/pikachu.png --length 16 --preview"
