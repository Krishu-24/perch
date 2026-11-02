<div align="center">

# Perch

**Claude, perched in your MacBook's notch.**

See what every Claude Code session is doing and how much of your plan you've used,
without leaving what you're working on.

![Version](https://img.shields.io/badge/version-1.0.0-d97757)
![macOS](https://img.shields.io/badge/macOS-14%2B-black)
![License](https://img.shields.io/badge/license-GPL--3.0-blue)

<img src="docs/images/claude-tab.png" alt="The Claude tab in the open notch: plan limits on the left, three sessions on the right" width="680">

</div>

---

## Contents

- [What Perch does](#what-perch-does)
- [How it works](#how-it-works)
- [Install](#install)
- [Using Perch](#using-perch)
- [Security and privacy](#security-and-privacy)
- [Customize it](#customize-it)
- [Build from source](#build-from-source)
- [Troubleshooting](#troubleshooting)
- [Uninstall](#uninstall)
- [Credits and license](#credits-and-license)

---

## What Perch does

Perch is an independent notch app for macOS, built on [Boring Notch](https://github.com/TheBoredTeam/boring.notch),
with Claude added. It is not made by Anthropic or The Bored Team. Hover over the notch and you get two tabs: **Home** (music, calendar, battery,
webcam mirror, all from Boring Notch) and **Claude**.

| | Feature | What you see |
|---|---|---|
| 📊 | **Plan limits** | Your five-hour and weekly usage as bars that turn green → amber → red, with "Resets in 2h 13m". |
| 🟠 | **Live sessions** | Every Claude Code session: *Working* (with the tool it's using), *Needs you*, or *Your turn*. |
| ✋ | **Needs-you alerts** | When Claude is waiting for your approval, the closed notch shows a pulsing amber hand, even over music. |
| ✻ | **Closed-notch status** | While Claude works, the closed notch shows Claude's spark and your five-hour usage. |
| ↗️ | **Jump back** | Click a session to bring the Claude app or your terminal to the front. |
| ⚙️ | **Settings page** | Turn the closed-notch status on or off, open the notch automatically when Claude needs you, and check the connection. |

It works with Claude Code in the **Claude desktop app's Code tab** and in **any terminal**.

<p align="center">
  <img src="docs/images/closed-notch.png" alt="The closed notch: Claude working with 18% used; a session needing you at 93% used; three sessions waiting" width="300">
  <br>
  <sub>The closed notch while Claude works, when a session needs you, and when three are waiting.</sub>
</p>

---

## How it works

Perch has two halves that talk through two small files on your Mac:

```
 Claude Code (desktop app or terminal)
        │
        │  perch-bridge mod  ── listens to session, turn, permission and usage events
        ▼
 ~/Library/Application Support/Perch/
        ├── sessions/<session id>.json   what each session is doing
        └── limits.json                  five-hour and weekly usage
        ▲
        │  reads once a second
        │
 Perch.app (the notch)
```

1. **`perch-bridge`** is a Claude Code *mod*: a small plugin that runs inside Claude Code. When a
   session starts, a turn starts or ends, a tool runs, a permission dialog appears or your usage
   changes, it writes a few lines of JSON.
2. **Perch.app** reads those files and draws them in the notch.

Nothing goes over the network, and the two halves never talk to each other directly.

---

## Install

### What you need

- A Mac with **macOS 14 Sonoma or later** (Apple silicon or Intel). Made for MacBooks with a notch;
  on other screens it shows as a small bar at the top centre.
- **Claude Code** 2.1.287 or later, or the **Claude desktop app** 2.1.286 or later (for its Code tab).
- A Claude **Pro or Max** plan, if you want plan limits. Sessions show on any plan.

### Step 1 · Install the app

1. Download **`Perch-1.0.0.zip`** from the [latest release](https://github.com/Krishu-24/perch/releases/latest).
2. Unzip it and drag **Perch.app** into **Applications**.
3. Open it. macOS will say it *can't check Perch for malicious software*. This is because the
   app isn't signed with a paid Apple Developer ID. To open it anyway:
   - open **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** next to Perch, **or**
   - run this once in Terminal:
     ```bash
     xattr -dr com.apple.quarantine /Applications/Perch.app
     ```
4. Perch walks you through a short welcome. Hover over the notch to try it.

> [!TIP]
> Want it to start with your Mac? **Perch menu bar icon → Settings → General → Launch at login.**

> [!IMPORTANT]
> Only one notch app can use the notch at a time. Quit Boring Notch, NotchNook, Vibe Notch,
> Open Island and the like before you open Perch.

### Step 2 · Connect Claude Code

Install the `perch-bridge` mod once. Every Claude session you start afterwards uses it.

**In the Claude desktop app:** click **+** next to the prompt box → **Plugins** → **Add marketplace**,
enter `Krishu-24/perch`, then add **perch-bridge**.

**Or in a terminal**, at the `claude` prompt:

```
/plugin install perch-bridge --marketplace Krishu-24/perch
```

Answer `y` to add the marketplace and press Enter for the user scope.

### Step 3 · Check it works

1. Start a **new** Claude session (ones already open don't load the mod) and send any message.
2. Hover over the notch and click **Claude**. Your session appears, and once Claude replies,
   your plan limits fill in.
3. **Perch → Settings → Claude** should say **Connected**.

---

## Using Perch

### The Claude tab

<img src="docs/images/near-limit.png" alt="The Claude tab close to the five-hour limit: a red 93% bar" width="560">

| Part | Meaning |
|---|---|
| **5-hour / Weekly bars** | How much of each plan window you've used. Green under 70%, amber under 90%, red from 90%. |
| **Resets in …** | When that window starts over. |
| **✋ amber row** | Claude is waiting for you to approve something. The tool's name is shown in amber. |
| **✻ spinner** | Claude is working. The tool it's running is shown in grey. |
| **🟢 dot** | Claude finished and it's your turn. The time on the right is how long ago. |
| **Click a row** | Brings the Claude app, or your terminal, to the front. |

Sessions appear after their first message. Finished sessions drop off after 30 minutes of quiet,
and a session that stops reporting (for example, after a crash) is hidden after 2 hours.

### The closed notch

| What's showing | When |
|---|---|
| **✻ spark** + your five-hour % | A session is working and no music is playing. |
| **Pulsing ✋** + your five-hour % | A session needs you. Takes the notch even over music. |
| **Pulsing ✋** + a number | That many sessions need you. |

### Settings → Claude

| Setting | Default | What it does |
|---|---|---|
| Show Claude activity on the closed notch | On | The spark and hand described above. |
| Open the notch when Claude needs you | Off | Pops the notch open on the Claude tab the moment a session starts waiting. |
| Status / Active sessions / Limits updated | — | Whether the mod has connected, and how fresh the data is. |
| Show Data Folder in Finder | — | Opens `~/Library/Application Support/Perch`. |

---

## Security and privacy

Perch was built to be safe to run all day next to your code. The full threat model is in
[SECURITY.md](SECURITY.md). In short:

### 🔒 The mod (`perch-bridge`)

- **Never touches the network.** It makes no requests of any kind.
- **Never sees your login.** It doesn't read your Claude token, Keychain, cookies or settings files.
  Plan limits come from the same numbers Claude Code already shows in `/usage`.
- **Reads exactly one environment variable,** `HOME`, to find your Library folder.
- **Writes only inside** `~/Library/Application Support/Perch/`.
- **Can't approve or block anything.** It only listens. Every hook passes the event on
  unchanged, and if the mod itself fails, Claude Code carries on as if it weren't there.
- **Small and checkable.** About 120 lines of TypeScript in
  [`claude-mod/perch-bridge/hooks/register.ts`](claude-mod/perch-bridge/hooks/register.ts).
  `claude plugin validate claude-mod/perch-bridge` lists every event it hooks and every call it makes.

### 🛡️ The app (`Perch.app`)

- **Runs in the macOS App Sandbox** with the hardened runtime. Its one file exception is
  read/write access to `~/Library/Application Support/Perch/`, so it can read the mod's files
  and delete old ones. It can't open the rest of your files.
- **One hardened-runtime check is relaxed:** library validation. The release is signed without a
  developer identity, so macOS can't match the bundled frameworks to the app and would refuse to
  launch it otherwise. [SECURITY.md](SECURITY.md) explains this and how to remove it if you sign
  with your own Apple Developer ID.
- **No telemetry, no analytics, no accounts.** This was checked in Boring Notch's source and binary
  before building on it.
- **Automatic updates are switched off.** The Boring Notch update feed is removed, so nothing can
  replace Perch behind your back. You update by downloading a new release.
- **Network use is all inherited from Boring Notch**, and none of it involves Claude:
  - **Album art:** fetched from wherever your music player says it is.
  - **Music animation:** one small animation file from LottieFiles.
  - **Lyrics:** looked up on lrclib.net, *only* if you turn lyrics on (off by default).
  - **YouTube Music:** talks to `localhost` only.

### 📄 What's stored, and for how long

| File | Contents | Kept |
|---|---|---|
| `sessions/<id>.json` | Session ID, project folder path, first 120 characters of your latest prompt, current tool name, status, time. | Deleted after 24 hours. |
| `limits.json` | Five-hour and weekly usage percentages and reset times. | Overwritten as it changes. |

These are plain text files, readable by any app running as you, just like Claude Code's own
history in `~/.claude`. Delete the folder at any time; it's recreated on the next event.

### 🔑 macOS permissions

Perch only asks when you use the feature that needs it:

| Permission | Used for |
|---|---|
| Calendars and Reminders | The calendar on the Home tab. |
| Camera | The mirror on the Home tab. |
| Automation (Music, Spotify) | Music controls. |
| Accessibility | Replacing the volume and brightness pop-ups. |

The Claude features need **no** macOS permissions.

### ⚠️ Know before you install

- The release isn't **notarized** by Apple, so macOS can't vouch for it. That's why the first
  launch needs *Open Anyway*. If you'd rather not trust a downloaded build, [build it yourself](#build-from-source).
  It takes about two minutes.
- Install the mod only from **this** repository (`Krishu-24/perch`), never from a copy.

---

## Customize it

Everything Claude-related lives in two places, so it's easy to make your own.

### Project layout

```
perch/
├── boringNotch/
│   ├── Claude/                       ← everything Perch adds to the app
│   │   ├── ClaudeView.swift          the Claude tab: limits panel and session rows
│   │   ├── ClaudeLiveActivity.swift  what the closed notch shows
│   │   ├── ClaudeSettings.swift      Settings → Claude
│   │   ├── ClaudeSessionStore.swift  reads the mod's files, filters and sorts sessions
│   │   ├── ClaudeUsage.swift         parses limits.json
│   │   ├── ClaudeFormatting.swift    "Resets in 2h 13m", "4m ago"
│   │   └── StatusIcons.swift, ProcessingSpinner.swift, TerminalColors.swift
│   └── …                             Boring Notch (Home tab, music, HUDs, settings)
├── claude-mod/perch-bridge/          the Claude Code mod
│   ├── hooks/register.ts             what it listens to and writes
│   └── hooks/register.test.ts        its tests
├── .claude-plugin/marketplace.json   lets Claude Code install the mod from this repo
├── scripts/
│   ├── claude-tests/run.sh           run every test
│   └── claude-tab-snapshots/render.sh  render the Claude UI to PNGs
└── docs/images/                      the screenshots in this README
```

### Common changes

| You want to… | Change |
|---|---|
| Change the colours | `TerminalColors` in `boringNotch/Claude/TerminalColors.swift`. |
| Move the green/amber/red thresholds | `ClaudeLimitBar.tint(for:)` in `ClaudeView.swift`. |
| Keep finished sessions longer | `quietTimeout` in `ClaudeSessionStore.swift`. |
| Show something else on the closed notch | `ClaudeLiveActivity.swift`. |
| Send more (or less) from Claude Code | `register.ts`. The fields you add show up in `ClaudeSession` once you add them there. |
| Rename the tab or its icon | `tabs` in `boringNotch/components/Tabs/TabSelectionView.swift`. |

### Check your changes

```bash
# Logic tests (time strings, limits parsing, session filtering) and the mod's tests
scripts/claude-tests/run.sh

# Render the Claude tab and closed notch with sample data → build/claude-snapshots/*.png
scripts/claude-tab-snapshots/render.sh
```

The mod's tests need the Claude Code CLI. If `claude` isn't on your PATH, point `CLAUDE_CLI` at it:

```bash
CLAUDE_CLI="$HOME/Library/Application Support/Claude/claude-code/<version>/<build>/claude.app/Contents/MacOS/claude" scripts/claude-tests/run.sh
```

### Working on the mod

Install it from your own checkout so edits take effect without publishing anything:

```bash
claude plugin marketplace add /path/to/perch
claude plugin install perch-bridge@perch
```

Claude Code then reads the mod straight from your folder. After an edit, run `/reload-plugins`
in a session, or start a new one.

---

## Build from source

You need **Xcode 26** or later.

```bash
git clone https://github.com/Krishu-24/perch.git
cd perch
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Release \
  -derivedDataPath build/DerivedData \
  CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= CODE_SIGN_STYLE=Manual build
open build/DerivedData/Build/Products/Release/Perch.app
```

`CODE_SIGN_IDENTITY=-` signs it for your Mac only, so you don't need an Apple Developer account.
Or open `boringNotch.xcodeproj` in Xcode, choose **Sign to Run Locally**, and press ⌘R.

---

## Troubleshooting

<details>
<summary><b>The Claude tab says "Claude isn't connected yet"</b></summary>

The mod hasn't written anything yet. Check that `perch-bridge` is installed (in a terminal:
`claude plugin list`), then start a **new** session and send a message. Sessions that were already
open when you installed it don't load it.
</details>

<details>
<summary><b>Sessions show, but the plan limits are empty</b></summary>

Limits arrive with Claude's first reply in a session, and only on a Pro or Max plan. API-key
and other non-subscription setups have no plan limits to show.
</details>

<details>
<summary><b>A session still says "Needs you" after I approved</b></summary>

The status changes back to *Working* when the approved tool finishes. A long-running command
keeps the hand up until it's done.
</details>

<details>
<summary><b>The notch shows nothing, or two things overlap</b></summary>

Another notch app is running. Quit it (Boring Notch, NotchNook, Vibe Notch, Open Island…) and
reopen Perch.
</details>

<details>
<summary><b>macOS won't open the app</b></summary>

See [Step 1](#step-1--install-the-app). Use *Open Anyway* or the `xattr` command once.
</details>

---

## Uninstall

1. Quit Perch (menu bar icon → Quit) and delete **Perch.app** from Applications.
2. Remove the mod: in a terminal, `claude plugin uninstall perch-bridge@perch`. In the desktop
   app, use **+ → Plugins**.
3. Delete its data: `rm -r ~/Library/Application\ Support/Perch`.
4. Optional, to remove its settings: `rm -r ~/Library/Containers/io.github.krishu-24.perch`.

---

## Credits and license

Perch stands on other people's open-source work:

| Project | License | What Perch uses |
|---|---|---|
| [Boring Notch](https://github.com/TheBoredTeam/boring.notch) | GPL-3.0 | The whole notch app Perch is built on. |
| [Vibe Notch](https://github.com/farouqaldori/vibe-notch) | Apache-2.0 | Status icons, spinner, colours and the session row layout. |
| [Open Island](https://github.com/Octane0411/open-vibe-island) | GPL-3.0 | The usage-limits parser. |
| [CapaTheNotch](https://github.com/maximfakel/capa-the-notch) | MIT | Its research showed how to read limits outside the terminal. |

Every copied file says where it came from. Third-party notices are in
[THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES).

**Perch is licensed under the [GNU General Public License v3.0](LICENSE)**, the same as Boring Notch.
In plain words:

- ✅ Use it, study it, change it, and share it, for free, for any purpose.
- ✅ Share your own modified version with anyone.
- 📌 If you share a version, share its source code under GPL-3.0 too, and keep the credits.

**Modification notice:** Perch is a modified version of Boring Notch 2.7.3, changed starting
3 November 2026. [CHANGELOG.md](CHANGELOG.md) lists what was added, removed and changed, and the
git history shows every change in detail.

> [!NOTE]
> Perch is an independent project. It is not affiliated with, endorsed by or supported by
> Anthropic or The Bored Team. "Claude" and "Claude Code" are trademarks of Anthropic, and
> "Boring Notch" belongs to The Bored Team; they are used here only to say what Perch works with
> and where it comes from.
