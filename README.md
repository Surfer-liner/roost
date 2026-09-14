<div align="center">

# 🐦 Roost

**Save and restore window layouts across all your monitors on macOS.**

Unplug your MacBook. Come back. Re-dock. One click — every window flies home.

![CI](https://github.com/Surfer-liner/roost/actions/workflows/ci.yml/badge.svg) ![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black?logo=apple) ![Swift](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white) ![License: MIT](https://img.shields.io/badge/License-MIT-green)

</div>

---

You know this dance.

You dock your MacBook and build the perfect workspace: browser on the big screen, editor front and center, Slack and terminal exiled to the side monitor. Then you unplug and leave for a meeting.

When you come back, macOS has swept every window into one sad pile on one screen. And you rebuild your workspace by hand. Third time today.

macOS **still** has no built-in way to remember window positions when displays disconnect and reconnect. Roost is that missing piece.

## Two buttons. That's the app.

|  |  |
|---|---|
| **Save Layout** | Remembers the exact position and size of every window on every display |
| **Restore Layout** | Puts every window back where it belongs — and relaunches apps that aren't even running |

No config files. No layout editor. No subscription. A bird lives in your menu bar and it has one job.

## The details that matter

- **A separate layout for every display setup.** Roost fingerprints your monitor arrangement. Triple-head at the office, ultrawide at home, bare laptop in a café — each setup remembers its own layout, and Restore always picks the right one.
- **Auto-restore.** Flip one toggle and Roost fixes your windows by itself a couple of seconds after your monitors reconnect. Plug in the cable, watch the windows fly.
- **Puts every window back and makes it stay.** Some apps (Telegram, JetBrains IDEs and other Electron/Java apps) re-home their own window a beat after they open, landing it on the wrong monitor. Roost keeps re-asserting each window's spot until it actually settles there — no more clicking Restore three times.
- **Reopens what's missing.** Quit apps get relaunched. An app running with fewer windows than you saved gets nudged to open the rest. Minimized windows are pulled out of the Dock — and windows you saved minimized go right back to it.
- **Native and weightless.** Pure Swift and AppKit, a single tiny binary. Instant start, zero CPU while idle, no Electron.
- **Private by design.** Layouts live in a local JSON file. Nothing ever leaves your Mac — no analytics, no network access at all.
- **Free and MIT.** Forever.

## Install

```bash
git clone https://github.com/Surfer-liner/roost.git && cd roost
make install
```

That builds Roost, drops it into /Applications and launches it.

On first run, macOS asks for **Accessibility** access — that's the API that lets Roost move other apps' windows. Grant it in **System Settings → Privacy & Security → Accessibility** and you're set.

Requires macOS 13+ and Xcode Command Line Tools. Zero dependencies.

## Use it

1. Arrange your windows until it feels right.
2. Menu bar 🐦 → **Save Layout**.
3. Live your life: unplug, present, travel, come back, dock.
4. 🐦 → **Restore Layout**. Done.
5. Optional: flip **Auto-Restore on Reconnect** and forget step 4 forever.

Save once per display setup — Roost keeps them all.

## How it works

Roost uses the macOS Accessibility API to read and set the exact frame of every standard window on every connected display. Each saved layout is keyed to a fingerprint of your display arrangement — resolutions and relative positions — so your three-monitor desk layout and your laptop-only layout never fight each other.

On restore, windows are matched by app and window title, with a fallback for titles that drift (looking at you, browser tabs). Missing apps get launched, and Roost keeps retrying placement for a few seconds while they start up.

Layouts are stored in `~/Library/Application Support/Roost/layouts.json`. It's your data — read it, sync it, delete it.

## FAQ

**Why do my Mac windows get scrambled when I disconnect or reconnect a monitor?**
When displays change, macOS reflows every window onto whatever screens remain — and forgets where everything was. There is no built-in "put it back". That's the entire reason Roost exists.

**Does it handle Spaces / multiple desktops?**
Roost restores windows on the current Space. macOS doesn't offer apps a public API for moving windows between Spaces.

**I closed a window, not the whole app. Will Restore bring it back?**
Roost pokes the app until it opens a window again, then parks that window on the saved spot. The one thing no public macOS API can do is resurrect a specific closed document — if the app reopens it itself (most do on relaunch), Roost places it; otherwise you get a fresh window in the right place.

**A window didn't come back.**
A few apps speak Accessibility poorly (some Java and niche ones). Roost places everything that responds. Fullscreen windows are technically Spaces, so they're left alone.

**Restore does nothing.**
Check that Roost is enabled in System Settings → Privacy & Security → Accessibility. If you rebuilt from source, macOS may want the permission re-granted — toggle it off and on.

## Development

```bash
make app       # build Roost.app into build/
make test      # unit tests — pure Swift, no Xcode required
make selftest  # live drills: Roost opens TextEdit and Calculator, scrambles,
               # minimizes, closes and quits their windows, fights the restorer
               # by shoving a window away, then checks every frame landed home
```

`make selftest` runs through the installed app, so it uses the Accessibility permission you already granted. It only ever touches TextEdit and Calculator, and it skips them entirely if they're already running with your stuff.

**Keeping Accessibility permission across rebuilds.** macOS ties the Accessibility grant to the app's code signature, and a plain rebuild re-signs with a throwaway identity — so you'd have to re-grant every time. To avoid that, create a stable local signing identity once and build with it:

```bash
make dev-cert  # one time: creates a self-signed "Roost Local Dev" identity
make dev       # build + install signed with it; grant Accessibility once, forever
```

## Roadmap

- [ ] Global hotkeys
- [ ] Multiple named layouts per display setup
- [ ] Homebrew cask, signed and notarized releases

---

<div align="center">

**If Roost just saved your morning, star the repo ⭐ — that's how the other multi-monitor people find it.**

MIT © Roost contributors

</div>
