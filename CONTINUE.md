# Continuing work on Perch

A handoff for the next session, local or cloud. Read this first, then `README.md` (what Perch does
and how it's built) and `SECURITY.md` (what each piece may do).

## What Perch is

A macOS notch app for Claude Code, forked from Boring Notch 2.7.3 (GPL-3.0). Three pieces talk only
through files in `~/Library/Application Support/Perch/`:

| Piece | Where | Runs | Builds with |
|---|---|---|---|
| **Perch.app** (the notch) | `boringNotch/` (the Claude parts in `boringNotch/Claude/` and `boringNotch/Dev/`) | Sandboxed | Xcode 26, `boringNotch.xcodeproj` |
| **Perch Helper** (terminal drop-down, widgets, data collector) | `helper/` (Swift package) | Not sandboxed, inside `Perch.app/Contents/Library/LoginItems/` | `swift build` |
| **perch-bridge** (Claude Code mod) | `claude-mod/perch-bridge/` | Inside Claude Code | Nothing; TypeScript loaded by Claude Code |

Files: `sessions/<id>.json` and `limits.json` (from the mod), `dev.json` and `helper-state.json` (from
the helper), `settings.json` (from Perch). The `dev.json` format is `boringNotch/Dev/DevSnapshot.swift`,
which `helper/Sources/PerchDevCore/DevSnapshot.swift` links to; change it in one place.

## Where things stand (3 November 2026)

- **Published:** v1.3.0 is on GitHub as the latest release
  (https://github.com/Krishu-24/perch/releases/tag/v1.3.0) and installed on the owner's Mac.
- **Two competing 1.4.0 versions, not merged.** The owner asked to stop the terminal being covered when
  the notch opens, and to put the widgets in the drop-down with the terminal. Two sessions answered:
  - Branch **`dropdown-tabs`** (this file's branch): one drop-down with **Terminal** and **Widgets** tabs;
    desktop widgets optional and off by default; the notch won't open on hover while the drop-down is in
    front; the Dev tab's GitHub card opens the Widgets tab.
  - Commit **`c589e04`** (worktree `../perch-1.4`, branch `claude/laughing-bell-ofdhz1` on GitHub): hover to
    switch notch tabs with a "safe triangle" rule, the terminal above the notch with Perch closing beneath
    it via distributed notifications, desktop widgets only while Finder is in front, and a lock icon on the
    lock screen.
  - **Decision pending:** which to keep, or how to combine them. Don't merge either into `main` until the
    owner says. Both bump the version to 1.4.0.

## How to work on it

```bash
# Every test: app logic (37 checks), helper parsers (15 XCTest), the mod (5 tests)
scripts/claude-tests/run.sh             # set CLAUDE_CLI to the Claude Code binary for the mod's tests

# See the UI without the notch (there's no other way to look; screenshots aren't available)
scripts/claude-tab-snapshots/render.sh                                   # → build/claude-snapshots/
swift run --package-path helper -c release WidgetSnapshots build/widget-snapshots

# Build the release: Perch + helper inside, signed ad hoc, zipped with a checksum
scripts/build-release.sh                # → build/release/Perch-<version>.zip
```

Install on the Mac: **build first, check it succeeded, then** quit Perch, replace
`/Applications/Perch.app`, and open it. Never delete the installed app before the new build exists.

Release: bump `MARKETING_VERSION` (4 places in `project.pbxproj`) and `helper/Resources/Info.plist`,
add a `CHANGELOG.md` entry, update the README's version badge and zip name, commit, tag `vX.Y.Z`, push,
then `gh release create vX.Y.Z build/release/Perch-X.Y.Z.zip build/release/Perch-X.Y.Z.zip.sha256`
with release notes. Ask the owner before publishing.

## Cloud sessions: what works

| Works in the cloud (Linux) | Needs the Mac |
|---|---|
| Editing any code or docs | Building Perch.app (Xcode, AppKit, SwiftUI for macOS) |
| `swift test` for `helper/` parsers, if a Swift toolchain is present (PerchDevCore is Foundation-only) | Rendering the snapshot PNGs (SwiftUI `ImageRenderer`) |
| Validating the mod with `claude plugin validate` | Installing and running Perch, `gh` signed in as the owner |
| Pushing a branch for review | Anything that needs to see the notch or the desktop |

So in the cloud: make the change, run what tests you can, push a branch, and say clearly what
wasn't built or seen. Then build, render and install on the Mac.

## Conventions

- Commit messages: a short imperative subject, a body saying what changed and why, ending with
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Credit copied code in the file header (Vibe Notch is Apache-2.0, Open Island GPL-3.0); keep
  `THIRD_PARTY_LICENSES` current. Perch stays GPL-3.0.
- UI copy: plain words, the user's view ("Changes in perch", "1 review waiting"). No scrolling in the
  notch: everything fits in one view.
- Privacy is a feature: the mod makes no network calls and reads no credentials; the helper never opens
  `~/.codex/auth.json` or `gh`'s token. Keep `SECURITY.md` in step with any new file, process or link.
- The owner shares this with a friend: keep the README install steps working for someone new.

## Ideas not done

- Real WidgetKit widgets (needs a paid Apple Developer account).
- A "Run tests" widget like the reference reel's (needs a test-runner integration).
- Approving Claude's permission requests from the notch.
