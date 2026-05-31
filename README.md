# TrueTone Manager

## Preface from a real, living human

I’m a designer, and I think every designer, photographer, or anyone working with color on an Apple computer knows one crucial thing: you must never forget to turn off True Tone. It subtly shifts the display’s color balance depending on the ambient lighting in the room.

In practice, this mode can completely ruin color grading work. There are plenty of horror stories online about people having to redo entire projects after accidentally working with True Tone enabled.

At the same time, outside of work, it can actually be quite pleasant. It reduces eye strain and makes the display feel warmer and more comfortable. That’s exactly what this app is for: it automatically switches True Tone depending on which application is currently in focus. Open Photoshop, for example - open this app from the menu bar and disable it there. From that point on, whenever Photoshop is in focus, True Tone will turn off automatically, and when you switch away, it will turn back on.

I hope this app turns out useful for you. I’ve wanted something like this for a long time but could never find it. Now, in the glorious age of LLMs, there’s no need to  search - I just ended up building it myself. Now I can watch how AI destroys my career with TrueTone off, yay!

Alright, you bag of bolts, go ahead and write the README:

## Description

TrueTone Manager automatically toggles macOS True Tone per application. A lightweight menu bar app that remembers your True Tone preference for each app and applies it on switch.

## Features

- **Per-app True Tone control** — enable/disable True Tone automatically when switching between apps
- **Menu bar icon** — shows current True Tone status, click to toggle for the active app
- **Persistent preferences** — per-app settings saved to disk and restored on relaunch
- **Launch at Login** — optional auto-start via `SMAppService`
- **No Dock icon** — runs silently as a menu bar accessory

## Requirements

- macOS 13 (Ventura) or later
- Apple Silicon Mac (`arm64`)

## Installation

### Homebrew (recommended)

Installs directly to `/Applications` and clears quarantine automatically:

```bash
brew tap mrtnby/tap https://github.com/martinrusetski/true-tone-manager
brew install --cask mrtnby/tap/true-tone-manager
open '/Applications/TrueTone Manager.app'
```

### DMG (pre-built)

Grab the latest `.dmg` from the [Releases](https://github.com/martinrusetski/true-tone-manager/releases) page, open it, and drag the app to `/Applications`.

> **Note:** The DMG build is ad-hoc signed but not notarized. macOS may block it on first launch. Remove quarantine with:
> ```bash
> xattr -cr /Applications/TrueTone\ Manager.app
> ```
> Then open normally. Alternatively, right-click the app and select **Open**, or go to **System Settings → Privacy & Security** and click **Open Anyway**.

## Usage

1. Launch the app — a ☀️ icon appears in your menu bar
2. Click the icon, then choose a **Disable TrueTone** / **Enable TrueTone** for the current app
3. Switch apps — TrueTone Manager applies your saved preference automatically

## How It Works

TrueTone Manager monitors app switches via `NSWorkspace` and controls True Tone through Apple's private `CoreBrightness` framework. Preferences are stored as JSON in:

```
~/Library/Application Support/TrueToneManager/preferences.json
```

## License

[MIT](LICENSE)
