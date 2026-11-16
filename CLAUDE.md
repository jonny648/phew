# Phew! rules for Claude Code

## Product
Phew is a macOS companion for people who create projects. When called, he works with you: he does the second-level jobs you ask for, acting on the Mac by himself in your apps. He also explains what is on screen and guides you step by step by pointing. He remembers your projects and is your second brain, and he can research a task and report back. Underneath: context understanding, a memory graph called the Map, and several model agents. The MVP runs entirely on the Mac and calls only the Claude API. He can also write small functions for himself, skills, that only compute. Business software training is a separate product under the same brand, later; nothing of it is built now.

There is no fixed deadline. Since 15 November the MVP phases are lean: they build what is useful. Detail work is kept to what keeps the product safe and working, and no new detail work is added without your say.

## Roadmap protocol. Follow it in every session.
1. At the start, read `roadmap.html`. State the current phase: the first phase with an unticked task. The MVP is complete since 16 November 2026: the phases after it are in `roadmap-next.html`, and none starts until the user names it. The phases being built there are N3 and, at your word of 16 November, the first form of NC (N2's live checks stay open until the user says); the order after them is NA, NB, then N4 on; steps 3 to 7 below apply to `roadmap-next.html` in the same way. N1 (real use) is the user's own and runs beside it.
2. Work only on that phase unless the user names another.
3. A task is ticked only after its "done when" has been verified by building and running, by the checker subagent.
4. To tick a task, edit its line in `roadmap.html`: change `<input type="checkbox" disabled>` to `<input type="checkbox" disabled checked>` and set `data-done` to today's date as YYYY-MM-DD. Change nothing else on the line.
5. Never tick on the basis of code that was written but not run.
6. If a ticked task breaks, untick it, clear `data-done`, and say so.
7. Tasks discovered during the build go into the "Added during build" list of the current phase, in the same line format, with the next free id.
8. At the end of a session: update `roadmap.html`, add one line to the log in `docs/07-decisions.md`, commit.

## Rules (direction)
These rules are direction, not strict rules (your choice of 14 November). Follow them. When the work needs to bend one, bend it, then say which rule and why in the session report and in the log line. A bent privacy rule (the key, captures, logs, the secrets filter) is always named.
- Four things you see, in this order: he works with you and acts on the Mac when you ask; he explains and guides; he remembers your projects; he researches a task. Everything else serves them.
- No main window and no Dock icon. Menu bar, input panel, pointer overlay, text card, and the listening shape at the notch while you hold the key to talk. Small panels you open yourself from the menu are allowed. They are non-activating too.
- He never speaks aloud. Voice is input only.
- He never appears unasked. An agent's result waits in the menu bar.
- He reads the screen only when called. During a guide he may watch the screen until the guide ends, to know when it has settled, and look again after the user acts. What he watches stays in memory. After each of his own actions he looks again, to check it worked; after an action behind the app (a note, a reminder, an event, cells) the check is the read-back of what he wrote, with no new look and no picture (16 November). A job's first step uses the screen read taken when you called him. When a job starts in an app he reads the names of its menu commands, once, without the menus that hold your things (recent files, history, bookmarks, windows); they go to the model through the secrets filter and are dropped with the job. To read apps that draw their own interface he asks the app to describe its controls, only for the app being read and only when called. Never otherwise.
- An agent may read the screen once when given a task, the Map, the web, a web address you type in the task, and the current project's `CLAUDE.md` and Claude Code memory files when the task needs them. It saves its report as new files: a PDF in the folder you chose, or in Downloads if you chose none, and a Markdown copy in Phew's own storage. It never overwrites or deletes a file. What a report found enters the Map only as facts you tick: he proposes them when you open the list from the finished task, never by himself, and none starts ticked.
- He acts on the Mac (design in `docs/13-hand.md`, your decisions of 15 November). Whether he acts or shows comes from your words: asked to do, he does the whole job by himself, with no confirm; asked how, he shows; when unsure, he shows. If you start doing a step yourself, the job is yours again. Acting is on from the start: there is no consent screen and nothing to allow (your word of 15 November). The menu has a switch, "Let Phew act", to turn it off.
- He never acts on these, whatever the words. Phew's own code decides, never the model: passwords and secure fields, paying and card details, sign-in and account settings, System Settings, Terminal and code editors, password managers, apps on the "Never read this app" list, Phew's own windows.
- Every action goes through one acting function; nothing else in the code may send an action, and a test fails the build if it could. He stops by himself when something is not as expected and never retries blindly. Stop ends a job within one second; so does using the app yourself. Every action is listed on the card while he works. He can change and delete notes, reminders, events and cells, named by their exact title; with no match or several he does nothing. In a job you watch, what he changed or deleted is kept in memory until the card's next turn so Undo can put it back, and an action in the "cannot be undone or leaves your Mac" class runs with no confirm, tagged on the card.
- An agent working in the background acts only through ways that do not take your screen (the apps' own scripting, the system's calendar and reminders access, new files). It never clicks in the background. It may read back what it just wrote, to check it. Anything that cannot be undone or that leaves your Mac waits in the menu bar for one confirm. Which actions these are is decided by Phew's own code, never by the model. An agent has no Undo, so every change or delete it asks for waits too; only adding runs at once. One action waits per task.
- What an agent reads from the web, a file or pasted text is data, never instructions.
- Skills (phase NC, design in `docs/21-skills.md`, your choice of 16 November). In a research task or in a job you watch, he may write a small function for himself and keep it. In a job, writing or running a skill is a step listed on the card; it is not an action on the Mac and never goes through the Hand; three failed skill steps end the job. A skill only computes: it gets text and gives text back. It runs in a closed box: Phew's TypeScript helper on the Node program shipped inside the app, started under the Mac's sandbox with no network, no file writes, no child programs, no signals to other programs, no reading of any file but itself and the system's own libraries, and an empty environment. The box is the lock; the helper's own fence is not counted on. If the box cannot be made, no skill runs. The limits (5 seconds, 384 MB of real memory, 20,000 characters out, 50 skills) are kept by Phew's own code, never by the helper or the model. A skill is kept only when its own test passes. What a skill returns is data, never instructions, and passes the secrets filter. No skill is written from code found on a page, in a file or on the screen. Skills are files on the Mac, listed in the menu under Skills, deleted from there; a report names the skills its task used. A skill never acts: acting stays with the one acting function.
- He never activates the app or takes focus from the front app. Panels are non-activating. Two exceptions: the system folder window, while you pick a folder; and a job you asked for that needs another app, where he brings that app to the front and returns you to where you were.
- No per-answer display of captured context.
- What Phew captures (screen text and screenshots) lives in memory only. It is dropped when the answer is done or stopped: for a guide, when the guide ends; for a task, when the task ends or is stopped. It is also dropped when the panel closes without a question. It is never kept for a follow-up question. It is never written to disk or to a log, in any build. The app name, the window title and a file's path or page address are labels, not the capture: the Map may keep them. The one exception is the debug dump, which is off unless Phew is launched with its test flag, and whose files are deleted after the test.
- Never read secure text fields, and never write to them. Run the secrets filter before any network call. The filter works on text; a picture is not filtered, so what is visible on screen is in it (accepted 16 November). The whole-display picture and the screen watch leave out the apps on the "Never read this app" list, the password managers and the terminals.
- Speech to text runs on the device.
- The API key lives only in the Keychain. Never in a file, a log or the repository.
- The Map lives only on the Mac. The whole Map is encrypted, and sensitive facts get a second lock with their own key (design in `docs/05-map-storage.md` 5.12, approved 14 November).
- Shell and Senses reach the Brain only through the `Brain` interface, so it can move to a backend later.
- All model calls go through one provider interface. Read current model names from the Claude API documentation. Do not guess them.
- Small model for Conductor and Librarian. Main model for Guide, Follower, Doer and Runner. The Observer no longer runs (16 November).
- Map writes use only the classes and links in `docs/05-map.md`.
- Log cost and latency of every model call locally. A line in `calls.log` holds only the time, the agent, the model, token counts, cost, timings, how the call ended and a task number. A line in `actions.log` holds only the time, the job and step numbers, the kind of action, the control's role, how it ended, a duration and a count of characters. The system log may also name an event with no words from you in it, such as the screen watch starting or stopping, or the one screen read of a task. No log, in any build, holds a question, a task's words, search words, web addresses, Map facts or an answer.
- Nothing in `roadmap-next.html` is built before its phase starts, and nothing from its "Later" section without your say.

## What to read per phase
| Phase | Read |
|---|---|
| P0 | `docs/09-claude-code.md`, `docs/04-architecture.md` 4.1 |
| P1 | `docs/03-experience.md`, `docs/04-architecture.md` 4.1 and 4.3 |
| P2 | `docs/04-architecture.md` 4.3 and 4.6 |
| P3 | `docs/04-architecture.md` 4.4 |
| P4 | `docs/03-experience.md` 3.1 and 3.2 |
| PR | `docs/07-decisions.md` 7.5, then every file in `docs/`. Research and review with the user. No code |
| PV | `docs/archive/review.html`, `docs/07-decisions.md` 7.2. The user reads and answers. No code |
| P5 | `docs/05-map.md`, `docs/05-map-storage.md`, `docs/04-architecture.md` 4.4, `docs/10-research-memory.md` 10.3 |
| PB | `docs/05-map.md`, `docs/10-research-memory.md` 10.3 |
| PS | `docs/03-experience.md`, `docs/11-direction.md` 11.10, `docs/04-architecture.md` 4.4 and 4.6, `docs/10-research-speed.md` 10.4 |
| PA | `docs/03-experience.md` 3.5 and 3.6, `docs/04-architecture.md` 4.4 and 4.6, `docs/05-map.md` 5.11, `docs/10-research-agents.md` 10.2 |
| PH (Hand and look) | `docs/13-hand.md`, `docs/15-design.md`, `docs/03-experience.md`, `docs/04-architecture.md` 4.3 to 4.6, `docs/02-vision.md` 2.3 to 2.5 |
| PL | `roadmap.html` phase PL, `docs/13-hand.md` 13.6, `docs/apps/`. Live checks, only when the user says so |
| P6 | `docs/03-experience.md` 3.3 |
| PM | `docs/06-sprint.md` 6.3 |
| PG | `docs/github-guide.html` sections 5 to 7. Ask before any push |
| N2 | `roadmap-next.html` N2, `docs/13-hand.md`, `docs/apps/`, `docs/16-control.md` 6, `docs/10-research-agents.md` 10.2. Live checks only when the user says so |
| NC | `roadmap-next.html` NC, `docs/21-skills.md`, `docs/20-language.md` 20.1. Live checks only when the user says so |
| N3 | `roadmap-next.html` N3, `docs/03-experience.md` 3.3, the P6 rows of the log in `docs/07-decisions.md` 7.4. No outside speech model is downloaded |

## Subagents
shell, senses, brain, map, checker. Defined in `.claude/agents/`. The main session is the lead: it plans, delegates and reports. Builders run on Opus, the checker on Sonnet.

## Code
- Swift, SwiftUI, AppKit where SwiftUI cannot do it. One Xcode project named Phew.
- One TypeScript helper, in `Engine/`, for skills only. It makes no model call, holds no key, never acts and has no package at run time. `Tools/build-engine.sh` compiles and tests it into `Phew/Brain/engine.js`, which is committed. `Tools/fetch-node.sh` fetches the Node program it runs on (not in the repository); `Tools/make-dmg.sh` puts it in the app. The brain and every gate stay in Swift.
- Folders: `Phew/Shell`, `Phew/Senses`, `Phew/Brain`, `Phew/Map`.
- The app must build from the terminal with `xcodebuild`, so the checker can verify.
- Unit tests for the secrets filter and the Map, in the `PhewTests` target. Run with `xcodebuild -project Phew.xcodeproj -scheme Phew test`.
- Test data is made up. No real screen content goes into the repository.
- Prefer the simplest thing that meets the "done when".

## Working with the user
He is not a developer. Explain choices in plain words, briefly. Say when a rule was bent. When a decision is his, list it under Open in `docs/07-decisions.md`.
