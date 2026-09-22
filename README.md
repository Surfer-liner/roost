<div align="center">

# Roost

**Save and restore window layouts across all your monitors on macOS.**

Unplug your MacBook. Come back. Re-dock. One click puts every window back where it belongs.

![CI](https://github.com/Surfer-liner/roost/actions/workflows/ci.yml/badge.svg) ![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black?logo=apple) ![Swift](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white) ![License: MIT](https://img.shields.io/badge/License-MIT-green)

</div>

---

You know this dance.

You dock your MacBook and build the perfect workspace: browser on the big screen, editor front and center, chat and terminal on the side monitor. Then you unplug and leave for a meeting.

When you come back, macOS has swept every window into one pile on one screen, and you rebuild the whole thing by hand. Third time today.

macOS still has no built-in way to remember window positions when displays disconnect and reconnect. Roost is that missing piece.

## Two buttons. That's the app.

|  |  |
|---|---|
| **Save Layout** | Remembers the exact position and size of every window on every display. |
| **Restore Layout** | Puts every window back where it belongs, and relaunches apps that are not even running. |

No config files. No layout editor. No subscription. It lives in your menu bar and has one job.

## The details that matter

- **A separate layout for every display setup.** Roost fingerprints your monitor arrangement. Triple-head at the office, ultrawide at home, bare laptop in a cafe: each setup remembers its own layout, and Restore always picks the right one.
- **Auto-restore on reconnect and at launch.** Flip one toggle and Roost fixes your windows by itself a couple of seconds after your monitors come back, and again when it starts after a reboot. Plug in the cable and they snap into place.
- **Survives macOS shuffling your monitors.** After a reboot or a re-dock, macOS often hands the same displays new coordinates. Roost remembers which display each window lived on and where inside it, so the layout still matches and every window lands on the right screen.
- **Puts every window back and makes it stay.** Some apps re-home their own window a beat after they open, landing it on the wrong monitor. Roost keeps re-asserting each window's spot until it actually settles there, so you never click Restore three times.
- **Rebuilds missing windows.** Quit apps get relaunched. An app running with fewer windows than you saved is asked to open the rest, even when its New Window command is buried in a submenu. Minimized windows are pulled back out of the Dock, and windows you saved minimized go right back to it.
- **Patient after a reboot.** An IDE that takes a minute to show its first window is waited for, not written off.
- **Remembers full-screen apps.** A window that was full-screen comes back full-screen on the display it belongs to, instead of being ignored or dumped into a floating window.
- **Native and weightless.** Pure Swift and AppKit in a single small binary. Instant start, no measurable CPU while idle, no Electron.
- **Private by design.** Layouts live in a local JSON file. Nothing ever leaves your Mac: no analytics, no network access at all.
- **Free and MIT.** Forever.

## Download

Grab the latest **Roost.dmg** from the [Releases page](https://github.com/Surfer-liner/roost/releases/latest), open it, and drag **Roost** into Applications.

Roost is free and not signed with a paid Apple certificate, so the first time you open it macOS will say it "cannot verify the developer". That is expected. To get past it once:

- **Right-click Roost in Applications → Open → Open**, or
- open it once, then go to **System Settings → Privacy & Security** and click **Open Anyway**.

You only do this once. After that Roost launches normally.

On first launch, macOS asks for **Accessibility** access. That is the API that lets Roost read and move other apps' windows. Grant it in **System Settings → Privacy & Security → Accessibility** and you are set.

Requires macOS 13 or later.

## Build from source

```bash
git clone https://github.com/Surfer-liner/roost.git && cd roost
make install
```

That builds Roost, drops it into /Applications, and launches it. Needs the Xcode Command Line Tools; zero third-party dependencies. To build the disk image yourself, run `make dmg`.

## Use it

1. Arrange your windows the way you want them.
2. Open the Roost menu and click **Save Layout**.
3. Live your life: unplug, present, travel, come back, dock.
4. Open the Roost menu and click **Restore Layout**.
5. Optional: flip **Auto-Restore on Reconnect & Launch** and skip step 4 forever.

Save once per display setup. Roost keeps them all.

### From the command line

Roost also answers two flags, so you can wire it to a hotkey tool or a script:

```bash
/Applications/Roost.app/Contents/MacOS/Roost --save
/Applications/Roost.app/Contents/MacOS/Roost --restore
```

## How it works

Roost uses the macOS Accessibility API to read and set the exact frame of every standard window on every connected display. Each saved layout is keyed to the set of displays attached, identified by size and by which side of the main screen each one sits on, and every window is stored as an offset inside its own display. macOS likes to hand displays new coordinates after a reboot or a re-dock; Roost does not care, it puts each window back on the same display at the same offset. Your desk layout and your laptop-only layout never overwrite each other.

On restore, windows are matched to the saved layout per app, by title first and then by order for titles that drift. Missing apps are relaunched, apps short a window are asked to open one, and each window is re-placed until it holds its position, all within a few seconds.

Layouts are stored in `~/Library/Application Support/Roost/layouts.json`. It is your data: read it, sync it, delete it.

## FAQ

**Why do my Mac windows get scrambled when I disconnect or reconnect a monitor?**
When displays change, macOS reflows every window onto whatever screens remain and forgets where everything was. There is no built-in "put it back". That is the entire reason Roost exists.

**Does it handle full-screen apps?**
Yes. Roost remembers which windows were full-screen and which display they were on, and puts them back into full-screen there. Moving a full-screen window to a different display is best-effort, since macOS is finicky about it; if it can't reach the exact display it still restores the window to full-screen rather than leaving it stranded.

**Does it handle Spaces and multiple desktops?**
Roost restores windows on the current Space. macOS gives apps no public API for moving windows between regular Spaces, so windows parked on another desktop are left alone.

**I closed a window, not the whole app. Will Restore bring it back?**
Roost asks the app to open a window again, then parks it on the saved spot. No public macOS API can resurrect a specific closed document, so if the app reopens it on its own you get it back in place; otherwise you get a fresh window in the right place.

**Restore does nothing.**
Check that Roost is enabled in System Settings → Privacy & Security → Accessibility. If you rebuilt from source, macOS may want the permission re-granted; toggle it off and on, or use `make dev` (below) to keep it.

**Does it work with Stage Manager?**
Stage Manager manages windows itself and overrides manual placement, so turn it off for the displays where you want Roost to drive.

**A restored window came back as a tab instead of its own window.**
If you set System Settings → Desktop & Dock → *Prefer tabs when opening documents* to "Always", the system turns new windows into tabs for apps that support tabbing. Set it to "In Full Screen Only" (the default) if you want Roost to rebuild separate windows.

**I changed which display is my main one and Roost forgot my layout.**
Layouts are keyed to the geometry of your display arrangement, and making a different display primary shifts every window coordinate. Just Save once on the new arrangement; both are remembered separately.

## Development

```bash
make app       # build Roost.app into build/
make test      # unit tests, pure Swift, no Xcode required
make icon      # regenerate the app icon (Roost.icns) from code
```

**Keeping Accessibility permission across rebuilds.** macOS ties the Accessibility grant to the app's code signature, and a plain rebuild re-signs with a throwaway identity, so you would have to re-grant every time. Create a stable local signing identity once and build with it:

```bash
make dev-cert  # one time: creates a self-signed "Roost Local Dev" identity
make dev       # build and install signed with it; grant Accessibility once
```

## Roadmap

- [ ] Global hotkeys
- [ ] Multiple named layouts per display setup
- [ ] Homebrew cask, signed and notarized releases

---

<div align="center">

If Roost saved you a rebuild, star the repo so the next person with a docking station can find it.

MIT © Roost contributors

</div>
