# Phew! rules for Claude Code

## Product
Phew is a macOS companion for university students. When called, he explains what is on screen and guides the student step by step by pointing. Underneath: context understanding, a memory graph called the Map, and several model agents. The MVP runs entirely on the Mac and calls only the Claude API.

## Roadmap protocol. Follow it in every session.
1. At the start, read `roadmap.html`. State the current phase: the first phase with an unticked task.
2. Work only on that phase unless the user names another.
3. A task is ticked only after its "done when" has been verified by building and running, by the checker subagent.
4. To tick a task, edit its line in `roadmap.html`: change `<input type="checkbox" disabled>` to `<input type="checkbox" disabled checked>` and set `data-done` to today's date as YYYY-MM-DD. Change nothing else on the line.
5. Never tick on the basis of code that was written but not run.
6. If a ticked task breaks, untick it, clear `data-done`, and say so.
7. Tasks discovered during the build go into the "Added during build" list of the current phase, in the same line format, with the next free id.
8. At the end of a session: update `roadmap.html`, add one line to the log in `docs/07-decisions.md`, commit.

## Hard rules
- Explain and guide is the only visible feature. Everything else serves it.
- No main window and no Dock icon. Menu bar, input panel, pointer overlay, text card.
- He never speaks aloud. Voice is input only.
- He never appears unasked.
- He reads the screen only when called. During a guide he may look again after the user acts. Never otherwise.
- He never activates the app or takes focus from the front app. Panels are non-activating.
- No per-answer display of captured context.
- What Phew captures (screen text and screenshots) lives in memory only. It is dropped when the answer is done or the panel closes, and is never written to disk or to a log, in any build. The one exception is the debug dump, which is off unless Phew is launched with its test flag, and whose files are deleted after the test.
- Never read secure text fields. Run the secrets filter before any network call.
- Speech to text runs on the device.
- The API key lives only in the Keychain. Never in a file, a log or the repository.
- Shell and Senses reach the Brain only through the `Brain` interface, so it can move to a backend later.
- All model calls go through one provider interface. Read current model names from the Claude API documentation. Do not guess them.
- Small model for Conductor, Observer, Librarian. Main model for Guide.
- Map writes use only the classes and links in `docs/05-map.md`.
- Log cost and latency of every model call locally.
- Nothing from the "Later" section of the roadmap is built during the MVP.

## What to read per phase
| Phase | Read |
|---|---|
| P0 | `docs/09-claude-code.md`, `docs/04-architecture.md` 4.1 |
| P1 | `docs/03-experience.md`, `docs/04-architecture.md` 4.1 and 4.3 |
| P2 | `docs/04-architecture.md` 4.3 and 4.6 |
| P3 | `docs/04-architecture.md` 4.4 |
| P4 | `docs/03-experience.md` 3.1 and 3.2 |
| PR | `docs/07-decisions.md` 7.5, then every file in `docs/`. Research and review with the user. No code |
| P5 | `docs/05-map.md` |
| PT | The task's own "done when". Manual checks only the user can run |
| P6 | `docs/03-experience.md` 3.3, `docs/06-sprint.md` 6.3 |

## Subagents
shell, senses, brain, map, checker. Defined in `.claude/agents/`. The main session is the lead: it plans, delegates and reports. Builders run on Opus, the checker on Sonnet.

## Code
- Swift, SwiftUI, AppKit where SwiftUI cannot do it. One Xcode project named Phew.
- Folders: `Phew/Shell`, `Phew/Senses`, `Phew/Brain`, `Phew/Map`.
- The app must build from the terminal with `xcodebuild`, so the checker can verify.
- Unit tests for the secrets filter and the Map, in the `PhewTests` target. Run with `xcodebuild -project Phew.xcodeproj -scheme Phew test`.
- Test data is made up. No real screen content goes into the repository.
- Prefer the simplest thing that meets the "done when".

## Working with the user
He is not a developer. Explain choices in plain words, briefly. Ask before breaking a hard rule. When a decision is his, list it under Open in `docs/07-decisions.md`.
