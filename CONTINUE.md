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

## Where things stand (4 November 2026)

- **Published:** v1.3.0 is the latest GitHub release. **v1.4.0 is merged into `main`** and installed on
  the owner's Mac, but not yet published as a release.
- **1.4.0 combines two sessions' work.** Branch `dropdown-tabs` put the widgets in the drop-down (a Widgets
  tab beside Terminal); the cloud session's branch `claude/laughing-bell-ofdhz1` added hover-to-switch tabs
  with a "safe triangle" (`TabAim`), the drop-down above the notch with show/hide notifications to Perch, the
  notch's tabs along the drop-down's strip, desktop widgets that only appear while Finder is in front, and a
  lock icon. The merge keeps all of it: the strip's tabs are Home, Terminal, Widgets, Limits, Claude, Dev;
  Terminal and Widgets switch inside the drop-down, the rest put it away and open the notch on that tab.
  Desktop widgets default to *No, drop-down only* (`WidgetVisibility.off`).
- **Seen only in renders, not on screen:** the drop-down's strip and Widgets tab (AppKit, not renderable),
  and the lock icon. Ask the owner how they look.

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
