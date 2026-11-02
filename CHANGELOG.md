# Changelog

## 1.1.0 · 3 November 2026

### Added

- **Drop-down terminal.** Press Control-` anywhere and a terminal slides out of the notch. It keeps
  running while hidden; clicking elsewhere or pressing Control-` again puts it away.
- **Dev tab** with your GitHub contribution graph and streak, pull requests and reviews waiting on you,
  GitHub Actions runs, running dev servers, and the Git status of your recent projects. Click a pull
  request or run to open it, a dev server to open `localhost`, a project to open the terminal there.
- **Perch Helper**, a small companion inside Perch.app that runs the terminal and gathers the Dev tab's
  data, so Perch itself stays in the App Sandbox. GitHub data comes through the GitHub CLI (`gh`).
- **The closed notch follows you.** It shows whatever you aren't looking at: Claude while you're in the
  app that's playing (Prime in Safari, say), and what's playing while you're in Claude.
- A green check on the closed notch for 5 minutes after a session finishes, until you open Claude.
- `scripts/build-release.sh` builds Perch with the helper inside and zips it.
- Tests for the helper's parsers and for the closed-notch rule.

### Fixed

- Settings → Claude no longer says *Connected* just because Perch's data folder exists.

## 1.0.0 · 3 November 2026

The first release of Perch, built on Boring Notch 2.7.3.

### Added

- **Claude tab** in the notch: five-hour and weekly plan limits with reset times, and every
  Claude Code session as *Working*, *Needs you* or *Your turn*. Click a session to bring its app
  to the front.
- **Claude on the closed notch**: Claude's spark and your five-hour usage while a session works;
  a pulsing amber hand when one needs your approval, even over music.
- **Settings → Claude**: show or hide the closed-notch status, open the notch when Claude needs
  you, connection status and a shortcut to the data folder.
- **`perch-bridge`**, a Claude Code mod that reports sessions and plan limits through local files.
  It works in the Claude desktop app's Code tab and in the terminal, and installs straight from
  this repository.
- Tests for the app's Claude logic and for the mod, and a script that renders the Claude UI to PNGs.

### Removed from Boring Notch

- The Shelf: its tab, the AirDrop / Quick Share drop zone, opening the notch when a file is dragged
  near it, and its settings.
- Automatic updates from the Boring Notch feed.

### Changed from Boring Notch

- Named Perch, with its own bundle ID (`io.github.krishu-24.perch`), so it doesn't share
  settings with Boring Notch.
- The tab bar is always shown.
