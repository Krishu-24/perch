# Claude tab for Boring Notch

This branch (`claude-tab`, based on Boring Notch v2.7.3) adds a **Claude** tab to the notch:

- your Claude plan limits, five-hour and weekly, with reset times
- every running Claude Code session: working, needs you (waiting for approval), or your turn
- click a session to bring its app (Claude desktop or your terminal) to the front

It works for sessions in the Claude desktop app's Code tab as well as in a terminal.

## How it fits together

```
Claude Code ── notch-bridge mod ──► ~/Library/Application Support/BoringNotchClaude/
                                        sessions/<id>.json   limits.json
                                                    │
                       Boring Notch (Claude tab) ◄──┘  reads once a second
```

- `claude-mod/notch-bridge/` is a Claude Code mod. It listens to session, turn, permission and
  usage events and writes small JSON files. It reads only `HOME`, sends nothing over the network,
  and never blocks a tool call if it fails.
- `boringNotch/Claude/` is the tab. The app is sandboxed and may read only that one folder.

## Setup

1. Build: `xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Debug -derivedDataPath ../build/DerivedData CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= CODE_SIGN_STYLE=Manual build`
2. Install the mod once, from this folder (in a terminal; `claude` is the Claude Code CLI):

   ```
   claude plugin marketplace add ./claude-mod
   claude plugin install notch-bridge@boring-notch-claude
   ```

   Sessions started afterwards, in the terminal or the desktop app, load it. Edits to
   `claude-mod/notch-bridge` reach a running session with `/reload-plugins`.

To remove the mod: `claude plugin uninstall notch-bridge@boring-notch-claude`.

## Differences from stock Boring Notch

- Bundle ID `local.boringnotch.claude`, so it keeps its own settings beside the official app.
- The Sparkle updater is not started, since the official feed would replace this build.
- One sandbox exception: read-write access to `~/Library/Application Support/BoringNotchClaude/`.
- The Shelf is removed entirely: the Shelf tab and its AirDrop / Quick Share drop zone, opening
  the notch when a file is dragged near it, the Shelf settings page and its preferences, and the
  code behind them (`components/Shelf/`, `observers/DragDetector.swift`,
  `extensions/NSItemProvider+LoadHelpers.swift`). The tab bar now always shows Home and Claude.

## Credits

- [Boring Notch](https://github.com/TheBoredTeam/boring.notch), GPL-3.0: the app this is built on.
- [Vibe Notch](https://github.com/farouqaldori/vibe-notch), Apache-2.0: status icons, spinner,
  colors and the session row layout (`boringNotch/Claude/StatusIcons.swift`,
  `ProcessingSpinner.swift`, `TerminalColors.swift`, `ClaudeView.swift`).
- [Open Island](https://github.com/Octane0411/open-vibe-island), GPL-3.0: the usage-limit
  parser (`boringNotch/Claude/ClaudeUsage.swift`).
- [CapaTheNotch](https://github.com/maximfakel/capa-the-notch): its research note on reading
  limits outside the terminal pointed to the mods API.
