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
| **Network** | Only Boring Notch's music features: album art from your player, one LottieFiles animation, lrclib.net lyrics *if you turn lyrics on*, and `localhost` for YouTube Music. The Claude features use no network. |
| **Inherited entitlements** | Camera (mirror), Calendars (calendar), Apple Events for Music and Spotify, network client and server. These come from Boring Notch and are used only by its Home-tab features. |

## Data at rest

The mod writes plain JSON files that any process running as you can read:

- **`sessions/<id>.json`**: session ID, project folder path, the first 120 characters of your latest
  prompt, the current tool's name, a status word and a timestamp. Deleted after 24 hours.
- **`limits.json`**: five-hour and weekly usage percentages and their reset times.

This is the same exposure as Claude Code's own history in `~/.claude`. If a prompt snippet on
disk is a concern, delete `~/Library/Application Support/Perch` at any time, or remove the `prompt`
field in `register.ts`.

## Distribution

- Release builds are signed ad hoc and **not notarized**, so macOS asks you to allow the first
  launch. Building from source avoids trusting a downloaded binary.
- Install the mod only from `Krishu-24/perch`. A modified copy of a mod runs inside Claude Code
  with whatever calls its author gave it, so read `register.ts` before installing someone else's.
