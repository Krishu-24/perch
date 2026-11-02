#!/bin/sh
# Runs the Claude tab's logic tests, then the perch-bridge mod's tests.
# Usage: scripts/claude-tests/run.sh   (the mod's tests need the Claude Code CLI as `claude`, or CLAUDE_CLI)
set -e
cd "$(dirname "$0")/../.."
mkdir -p build
bin="build/claude-tests-bin"
# ClaudeSettings.swift needs the Defaults package, so it is left out.
sources=$(ls boringNotch/Claude/*.swift | grep -v ClaudeSettings.swift)
swiftc -o "$bin" $sources scripts/claude-tests/main.swift
"$bin"

cli="${CLAUDE_CLI:-claude}"
if command -v "$cli" >/dev/null 2>&1 || [ -x "$cli" ]; then
    "$cli" plugin test claude-mod/perch-bridge
else
    echo "Skipped the mod's tests: no Claude Code CLI found (set CLAUDE_CLI to its path)."
fi
