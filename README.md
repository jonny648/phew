# Phew!

A macOS companion for people who create projects. You call him with a shortcut and he works with you: he does the jobs you ask for in your apps, explains what is on screen, guides you step by step by pointing, remembers your projects, and researches a task alone.

Version 0.2.1 (the MVP was 0.1.0). Private repository.

## Install

Download `Phew-0.2.1.dmg` from the Releases page, open it and drag Phew to Applications. The app is signed with a development certificate, not notarised by Apple: on a Mac other than the owner's, macOS refuses to open it unless you right-click it and choose Open.

At first launch Phew asks for three things, once: a Claude API key (kept only in the Keychain), Accessibility, and Screen Recording. The microphone is asked the first time you hold the shortcut to talk.

## Use

- **Right Option + Right Command**, pressed: the ask panel. Type a question, or nothing to have him explain what is under the pointer.
- **Held**: speak, release. He hears on the Mac, in Italian or English.
- "Make the title bold": he does it. "How do I make it bold?": he shows you. "Research X and report": he works alone and the result waits in the menu bar.
- The menu bar icon holds the rest: Let Phew act, Never read this app, Memory (import, undo, recently deleted, export), Reports, API Key.

## Build

Needs Xcode 27 on macOS 26 or later.

```
xcodebuild -project Phew.xcodeproj -scheme Phew build
xcodebuild -project Phew.xcodeproj -scheme Phew test
```

Some tests open a window on screen; they run only with `TEST_RUNNER_PHEW_LIVE=1`.

## Where things are

| Path | Content |
|---|---|
| `Phew/` | The app: `Shell` (what you see), `Senses` (reading, hearing, acting), `Brain` (the agents), `Map` (the memory) |
| `PhewTests/` | Unit tests |
| `Tools/` | The practice app used by acting tests, the icon script, the DMG script |
| `roadmap.html` | The checklist of the build |
| `docs/00-now.md` | Where Phew is now, on one page |
| `docs/README.md` | Index of all docs |
| `docs/07-decisions.md` | Decisions and the log of every step |
| `CLAUDE.md` | Rules for every Claude Code session |
| `CHANGELOG.md` | What each version brought |

## Privacy, in short

He reads the screen only when called. What he reads lives in memory and is dropped when the answer ends. The memory (the Map) is encrypted and stays on the Mac. Speech is turned into words on the Mac. Your questions, the screen read with them and the few facts an answer needs go to the Claude API, after a filter that removes secrets. No log holds your words.
