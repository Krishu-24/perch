# Security

Perch runs next to your code all day, so it is built to need as little trust as possible.
This page says exactly what each part can do, and how to report a problem.

## Reporting a problem

Please report security issues privately through
[GitHub's "Report a vulnerability"](https://github.com/Krishu-24/perch/security/advisories/new)
on this repository rather than in a public issue. Problems in Boring Notch's own features
(music, calendar, HUDs) can also go to [Boring Notch](https://github.com/TheBoredTeam/boring.notch/security).

## The two parts and what each may do

### `perch-bridge`, the Claude Code mod

Source: [`claude-mod/perch-bridge/hooks/register.ts`](claude-mod/perch-bridge/hooks/register.ts), about 115 lines.

| | |
|---|---|
| **Events it listens to** | `session.start`, `turn.start`, `tool.call`, `classic.PermissionRequest`, `turn.complete`, `session.end`, `session.measure` |
| **Calls it makes** | `$.env.get("HOME")`, `$.session.id()`, `$.session.cwd()`, `$.clock.now()`, `$.fs.write()` |
| **Where it writes** | `~/Library/Application Support/Perch/sessions/<id>.json` and `…/Perch/limits.json` only |
| **Network** | None |
| **Credentials** | None. It never reads tokens, the Keychain, cookies, `~/.claude.json` or settings files. |
| **Effect on Claude** | None. Every hook calls `next(e)` with the event unchanged and returns its result. It never answers a permission request, so it cannot approve or deny anything. A hook that throws is caught (`.catch(... => next(e))`), so a bug in the mod cannot stop a tool from running. |

You can confirm the list of events and calls yourself:

```bash
claude plugin validate claude-mod/perch-bridge
```

### `Perch.app`, the notch

| | |
|---|---|
| **Sandbox** | App Sandbox on, hardened runtime on. |
| **File access** | One exception: read/write to `~/Library/Application Support/Perch/` (to read the mod's files and delete ones older than 24 hours). Otherwise only files you pick yourself. |
| **Updates** | Sparkle is never started and the update feed URL is removed, so the app cannot download or replace itself. |
| **Telemetry** | None. |
| **Lock screen** | With the lock icon on (the default), the notch stays on the lock screen through SkyLight, as Boring Notch's *Show notch on lock screen* does, but shows only a lock: no sessions, music or calendar, and it won't open. |
| **Network** | Only Boring Notch's music features: album art from your player, one LottieFiles animation, lrclib.net lyrics *if you turn lyrics on*, and `localhost` for YouTube Music. The Claude features use no network. |
| **Library validation** | Turned off (`com.apple.security.cs.disable-library-validation`). Release builds are signed ad hoc, with no developer identity, so macOS can't confirm that the bundled frameworks (Sparkle, Lottie, MediaRemoteAdapter) come from the same developer as the app and would refuse to start it. The rest of the hardened runtime stays on. If you sign Perch with your own Apple Developer ID, you can delete this entitlement. |
| **Inherited entitlements** | Camera (mirror), Calendars (calendar), Apple Events for Music and Spotify, network client and server. These come from Boring Notch and are used only by its Home-tab features. |

### `Perch Helper.app`, the companion

The one part of Perch **outside** the App Sandbox, because a terminal and tools like `git` can't work
inside it. It ships inside `Perch.app/Contents/Library/LoginItems/`, starts with Perch and quits with it.
Source: [`helper/`](helper/).

| | |
|---|---|
| **Sandbox** | Off, by design. Hardened runtime on. Signed ad hoc. |
| **Processes it starts** | Your login shell (only when you open the terminal); `git status`, `git log -1` and `git remote get-url` in up to 6 recent projects every 6 seconds; `lsof` for listening ports and `ps` for the dev servers' commands every 6 seconds; `gh auth status`, `gh api graphql` and `gh run list` every 3 minutes, only when `gh` is installed and signed in. Each runs with a time limit and with prompts turned off (`GIT_TERMINAL_PROMPT=0`, `GH_PROMPT_DISABLED=1`). |
| **Network** | None of its own. `gh` talks to api.github.com with the token `gh` stores. |
| **Credentials** | Never read. It doesn't open `gh`'s token, your Keychain or SSH keys. |
| **Files it writes** | `dev.json` and `helper-state.json` in `~/Library/Application Support/Perch/`. |
| **Files it reads** | The mod's `sessions/*.json` and `limits.json`, Perch's `settings.json`, the Git repositories you work in, and the last 512 KB of the newest three Codex session logs (`~/.codex/sessions/` and `~/.codex/archived_sessions/`, `rollout-*.jsonl` only) for Codex's limits. It never opens `~/.codex/auth.json`. |
| **Windows** | The drop-down terminal, and the desktop widgets: a borderless panel at desktop-icon level that never takes focus, on every Space. Clicking a widget opens a link in your browser or the terminal in a listed project. |
| **Notifications** | It posts two system-wide notifications with no contents, *terminal shown* and *terminal hidden*, so Perch keeps the notch shut beneath the terminal. To show the widgets only on the desktop it watches which app is frontmost (its bundle ID, nothing else). |
| **Keyboard** | One global hot key, Control-`, through Carbon's `RegisterEventHotKey`. It needs no Accessibility permission and receives only that combination. |
| **Links it accepts** | `perch-helper://terminal` (toggle), `perch-helper://terminal?show`, `perch-helper://refresh`, and `perch-helper://terminal?cd=<folder>`. The last is refused unless the folder is exactly one of the projects listed in `dev.json`, and the folder is quoted for the shell, so another app or a web page can neither point the terminal elsewhere nor inject a command. |

## Data at rest

The mod writes plain JSON files that any process running as you can read:

- **`sessions/<id>.json`**: session ID, project folder path, the first 120 characters of your latest
  prompt, the current tool's name, a status word and a timestamp. Deleted after 24 hours.
- **`limits.json`**: five-hour and weekly usage percentages and their reset times.
- **`dev.json`**: your recent projects' paths and Git status, dev servers (port, process name, folder),
  and the GitHub data shown on the Dev tab (login, contribution counts, pull request titles, run names).
- **`helper-state.json`**: up to 12 recent project folders and when each was last seen.

This is the same exposure as Claude Code's own history in `~/.claude`. If a prompt snippet on
disk is a concern, delete `~/Library/Application Support/Perch` at any time, or remove the `prompt`
field in `register.ts`.

## Distribution

- Release builds are signed ad hoc and **not notarized**, so macOS asks you to allow the first
  launch. Building from source avoids trusting a downloaded binary.
- Install the mod only from `Krishu-24/perch`. A modified copy of a mod runs inside Claude Code
  with whatever calls its author gave it, so read `register.ts` before installing someone else's.
