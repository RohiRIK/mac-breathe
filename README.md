# Mac Breathe

A calm, native macOS breathing guide. A soft orb grows as you breathe in and shrinks as you breathe out. It lives in your menu bar, and opens into a quiet full window when you want to focus.

<img src="docs/screenshots/window.png" width="640" alt="Mac Breathe focus window with an animated breathing orb">

[Download for macOS](https://github.com/RohiRIK/mac-breathe/releases/latest) · [Install](#install) · [Build](#build) · [Additional screenshots](docs/screenshots/)

## What it does

- **Breathing orb** that follows your breath: grows on the in-breath, rests on holds, shrinks on the out-breath. One soft word under it ("Breathe in", "Hold", "Breathe out"); nothing else while you breathe.
- **Two ways to run it**: a small menu bar panel, or a big window (full screen as a focus mode). The menu bar leaf breathes with you during a session.
- **18 techniques**, each explained (what it does, what it is best for, how to do it), plus your own custom rhythm:

  | Goal | Techniques |
  |---|---|
  | Calm & anxiety | Physiological Sigh · Extended Exhale · 7-11 · Humming Bee · Pursed-Lip |
  | Sleep | 4-7-8 · Sleep Taper · Belly Breathing |
  | Focus | Box Breathing · Triangle · Ujjayi (Ocean Breath) |
  | Balance & daily | Coherent Breathing · Equal Breathing · Alternate Nostril · Light Breathing |
  | Energy (advanced) | Bellows Breath · Skull Shining · Wim Hof Method |

- **A timer per breath**: every technique starts at its recommended length (e.g. 4 rounds of 4-7-8, 10 minutes of Coherent Breathing); change it under the orb. Sessions end after a full breath.
- **Sounds**: a gentle sound on each breath (Handpan, Singing Bowl, Koshi Chimes, Birds, Rain Stick, Ocean, Warm Pad), a bell at the start and end, and an optional quiet background (Birds in the Trees, Ocean Waves, Crystal Bowls, Handpan Music). Sounds are timed on the audio clock, so they land exactly on each phase change.
- **Feel and look**: trackpad taps, spoken cues, orb styles (Circle, Petals, Rings) and nine colour themes.
- **Practice**: pace, shorter holds for beginners, gradual slowdown, 3-2-1 lead-in, reminders during the day with quiet hours, and your streak and minutes.
- `Space` begins and stops; `⌥⌘B` from any app. Settings… (`⌘,`), Quit (`⌘Q`).

> **Safety**: the Energy techniques (Bellows, Skull Shining, Wim Hof) can cause dizziness or fainting. The app asks you to confirm before the first one. Always sit or lie down, and never practise them while driving, in or near water, or when pregnant. This app is not medical advice.

No network, no accounts, no dependencies. Swift 6 + SwiftUI, macOS 15+.

## Install

1. Download `MacBreathe-0.1.0.zip` from [Releases](https://github.com/RohiRIK/mac-breathe/releases/latest) and unzip it.
2. Move `MacBreathe.app` to Applications and open it. The leaf appears in your menu bar.
3. The app is not notarized by Apple, so macOS blocks the first launch. Open **System Settings › Privacy & Security**, scroll down, and click **Open Anyway** next to MacBreathe. Or in Terminal: `xattr -dr com.apple.quarantine /Applications/MacBreathe.app`.

macOS 15 or later, Apple silicon and Intel.

## Build

```bash
scripts/test.sh               # unit tests (works with Xcode or Command Line Tools only)
scripts/check.sh              # tests + universal release bundle (writes build/check-report.md)
open build/MacBreathe.app
```

## Repository layout

- `Sources/` — `MacBreatheCore` (techniques and breath plans), `MacBreatheUI` (SwiftUI views, session, sounds) and the `MacBreathe` app target.
- `Tests/` — unit tests for the technique catalog and breath plans.
- `Resources/` — `Info.plist` and the bundled breath sounds.
- `scripts/` — local test, bundle and check scripts.
- `docs/screenshots/` — app screenshots used above.
- `docs/previews/` — additional visual previews.
- `THIRD_PARTY_NOTICES.md` — audio attribution and licensing.

Run build commands on macOS with Xcode Command Line Tools. The release download above is the installation path; this repository contains the source.

## Credits

Breath sounds are CC0 recordings from [Freesound](https://freesound.org); see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## License

MIT
