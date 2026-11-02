#!/bin/sh
# Runs every test: the Claude and Dev tabs' logic, Perch Helper's parsers, and the perch-bridge mod.
# Usage: scripts/claude-tests/run.sh   (the mod's tests need the Claude Code CLI as `claude`, or CLAUDE_CLI)
set -e
cd "$(dirname "$0")/../.."
mkdir -p build
bin="build/claude-tests-bin"
# The settings pages need the app (the Defaults package, its accent colour), so they are left out.
sources=$(ls boringNotch/Claude/*.swift boringNotch/Dev/*.swift | grep -vE "(Claude|Dev)Settings.swift")
swiftc -o "$bin" $sources scripts/claude-tests/main.swift
"$bin"

(cd helper && swift test 2>&1 | grep -E "error|failed|Executed [0-9]+ tests" | tail -2)

cli="${CLAUDE_CLI:-claude}"
if command -v "$cli" >/dev/null 2>&1 || [ -x "$cli" ]; then
    "$cli" plugin test claude-mod/perch-bridge
else
    echo "Skipped the mod's tests: no Claude Code CLI found (set CLAUDE_CLI to its path)."
fi
