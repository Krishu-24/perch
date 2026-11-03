# Changelog

## 1.4.0 · 3 November 2026

### Added

- **Widgets in the drop-down.** The drop-down gains a Widgets tab beside Terminal, with every widget at full
  size. Control-` opens it on the tab you used last, both tabs keep their state while you switch, and
  clicking a project in the Git widget switches to the Terminal tab in that folder. The Dev tab's GitHub
  card opens it too.
- **Hover to switch tabs.** Rest the pointer on a notch tab and it switches; no click needed. The
  menu-aim ("safe triangle") rule keeps tabs you only cross on the way down to the content from
  switching, and the Terminal tab waits a little longer so sweeping past it never drops a terminal.
- **The other tabs stay in reach from the drop-down.** Its top strip shows the notch's tabs where the open
  notch has them, plus Widgets; resting on Home, Limits, Claude or Dev puts the drop-down away and opens
  the notch on that tab.
- **A lock on the notch while your Mac is locked**, which springs open in green when you unlock. While
  locked the notch shows only the lock and won't open. Settings → Advanced turns it off.

### Changed

- **Desktop widgets are optional, and off by default**, since they now live in the drop-down. Settings →
  Widgets → Also on the desktop: *On the desktop* (only while you're looking at the desktop, fading when you
  go back to an app), *Always*, or *No, drop-down only*.

### Fixed

- **The terminal is no longer covered.** It sat beneath the notch and at the same level as the menu
  bar's icons, so the open notch and status items drew over it. It now sits above both, the notch
  closes when it drops, and the notch won't open underneath it while it's down.
- Opening the terminal in a project while it was already down forgot which app to return to.
- A hide that was still animating could put the drop-down away right after you'd brought it back.

## 1.3.0 · 3 November 2026

### Added

- **Desktop widgets**, drawn by Perch Helper on your desktop beneath your windows: Git (projects to do,
  with changed files and commits to push or pull), GitHub (reviews waiting on you and your checks),
  Actions (running and failed runs, with a live timer), Dev servers (project, command and port),
  Contributions (the last 24 weeks and your streak), and Claude and Codex limits. Each leads with one
  big number. Settings → Widgets turns them off or moves them to another corner.
- **Limits tab**: Claude Code and Codex side by side, five-hour and weekly, with exact reset times.
- **Codex limits**, read from Codex's own session logs on your Mac.
- Dev servers now show what they run (`next dev`, `vite`, `uvicorn main:app`).

### Changed

- The notch's tabs are icons: Home, Terminal, Limits, Claude and Dev. The Terminal tab drops the terminal down.
- The Claude tab shows up to six sessions in two columns, with nothing to scroll.
- The Dev tab's card titles take the widgets' colours.

## 1.2.0 · 3 November 2026

### Changed

- **The Dev tab fits in one view, with nothing to scroll.** The contribution graph anchors the left; four
  cards (pull requests, Actions, dev servers, Git) each answer one question in a word or two, such as
  *1 review waiting* or *Changes in perch*. Cards that need you are outlined in amber, failures in red,
  and every card is a single click to the thing it describes.

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
