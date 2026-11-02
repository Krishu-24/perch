#!/bin/sh
# Renders the Claude tab with sample data to PNGs.
# Usage: scripts/claude-tab-snapshots/render.sh [output folder]   (default: build/claude-snapshots)
set -e
cd "$(dirname "$0")/../.."
out="${1:-build/claude-snapshots}"
bin="build/claude-snapshots-bin"
mkdir -p build
# ClaudeSettings.swift needs the Defaults package, so it is left out.
sources=$(ls boringNotch/Claude/*.swift boringNotch/Dev/*.swift | grep -v ClaudeSettings.swift)
swiftc -O -o "$bin" \
    $sources \
    scripts/claude-tab-snapshots/main.swift
"$bin" "$out"
