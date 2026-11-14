# 4. Architecture

Two views. Section 4.1 is what the MVP builds. Sections 4.2 to 4.7 are the full target, so nothing built now has to be thrown away.

## 4.1 MVP architecture: everything on the Mac

One Swift app, one repository, no cloud of your own. The only outside call is to the Claude API.

```
PHEW.APP (Swift, on your Mac)
  Shell     menu bar item, input panel, pointer overlay, text card
  Senses    window text and positions, screenshot, speech to text, secrets filter
  Brain     Conductor, Observer, Guide, Follower, Librarian, Runner
            behind one interface, so it can move to a backend later
  Map       SQLite file with text search. Stored only on the Mac
  Keychain  your Claude API key
        |
        v
  Claude API   small model for Conductor, Observer, Librarian
               main model for Guide, Follower, Runner
               web search and web fetch run at Anthropic, for the Runner
```

Why local first: no accounts, no servers, no sync, no signing programme. It removes about half of the work and none of the main problem.

The rule that keeps the future open: the Shell and Senses talk to the Brain only through one interface. Moving the Brain to a backend later changes one file.

Running it without the Apple Developer Program: build and run from Xcode, signed with the free personal team of your Apple ID. This keeps the Accessibility and Screen Recording permissions between builds. Verify on day 1.

## 4.2 Target overview

```
MAC APP (Swift)
  Presence   notch panel, menu bar item, pointer overlay
  Senses     window text, screenshots, microphone, system audio
  Hands      clicks, typing, scripts in other apps
  Local      cache, on-device speech, secrets filter
        |
        v
BACKEND (cloud)
  Gateway    sign in, limits, routes every model call
  Brain      conductor plus specialist agents
  Jobs       long tasks that run in the background
  Data       database with the Map, vectors, files
        |
        v
WEBSITE
  Landing page, dashboard, the Map view
```

## 4.3 Mac app modules

| Module | What it does | Built with | MVP |
|---|---|---|---|
| Menu bar home | Phew's home and controls | SwiftUI menu bar item | Yes |
| Notch home | Character, states, eggs | Borderless panel placed around the notch | Later |
| Input panel | A few typed words at the cursor | Non-activating panel | Yes |
| Pointer overlay | Second cursor, highlight, text card | Transparent full-screen window that ignores the mouse | Yes, simple |
| Window reader | Text, structure and position of elements | macOS Accessibility API | Yes |
| Screen capture | A picture with the text on every call | ScreenCaptureKit | Yes |
| Voice in | Speech to text on the device | Apple speech, or WhisperKit | Yes, last |
| Secrets filter | Removes keys, card numbers, password fields | Local rules | Yes |
| Local store | The Map: things, links and past questions. The last turns of a conversation stay in memory only | SQLite | Yes |
| Lecture capture | Microphone and system audio | AVFoundation, ScreenCaptureKit audio | Later |
| Hands | Press, type, scroll, scripts | Accessibility actions, AppleScript, Shortcuts | Later |
| Updates | Signed, notarised, automatic | Developer ID, Sparkle | Later |

Positions from the Accessibility API let Phew point at the exact button. When an app exposes nothing, the main model returns coordinates from the screenshot.

## 4.4 The brain: agents and roles

| Agent | Job | Model | MVP |
|---|---|---|---|
| Conductor | Understands the request, chooses who works | Small | Yes |
| Observer | Turns window text and screenshot into a clean context packet | Small, with vision | Yes |
| Guide | Explains and produces pointing steps. The main agent | Main, with vision | Yes |
| Follower | During a guide, looks at the screen after each action and says which step you are on, so the guide moves on by itself | Main, with vision. The small model missed steps done at once in testing | Yes |
| Librarian | Writes what was learned to the Map after each answer. Reading before an answer is done by Phew's own code, with no model call | Small | Yes |
| Runner | Researches a task alone: reads the screen once, the Map, the project's Claude Code files when needed, and the web, in a loop with limits, then reports. The Runner itself has no tool that writes. When the report is ready, Phew's own code saves it as a new PDF in the folder you chose or in Downloads, with a Markdown copy in Phew's own storage | Main, with web search and web fetch | Yes |
| Scribe | Lecture transcript to key points | Main | Later |
| Hand | Actions in other apps | Main | Later |
| Keeper | Nightly housekeeping of the Map | Small | Later |

Model provider: Claude API. Small means the Haiku class, main means the Sonnet class. The coding agent must read the current model names from the API documentation instead of guessing them.

Flow of one request:

1. You press the shortcut or hold the key and say "I don't get this".
2. Senses build the raw packet. Observer cleans it.
3. Phew's own code adds what the Map knows about this project and topic, and the last turns of the conversation as text. It is a text search, with no model call (see `05-map.md`). The Guide can also search the Map itself when it needs more.
4. Conductor sends it to Guide.
5. Guide streams an explanation and steps, each tied to an element on screen.
6. The pointer shows them.
7. After each thing you do, Follower looks at the fresh screen and moves the pointer to the step you are on. No Next button.
8. Librarian records what happened.

Following a guide faster (phase PS). The Guide marks each step that needs only a click. On such a step a direct hit on the marked target moves to the next step at once, with a "looking" motion on the pointer. The look then confirms, and a wrong advance steps back. A direct hit is a press and release without a drag, inside the marked element, or inside the ring (22 points) around a marked point. Steps that need typing, dragging or choosing wait for the look. So does the last step, so the card never closes on a guess. During a guide a screen watch tells Phew when the screen has settled. Its rules are in 4.6.

Flow of one task: you type or say a task. The Conductor chooses the task route. Before the first task the consent screen is shown (`03-experience.md` 3.5). The Runner gets your task and the one screen read made when you called him. It can search the Map with the same search tool the Guide has, and read the project's `CLAUDE.md` and memory files with `read_project_memory` when the task needs them (see `05-map.md` 5.10). It then searches and reads the web until it can answer or reaches a limit. Up to 3 tasks run at once (first proposal), each with its own limits and its own Stop. A mark in the menu bar shows how many are working. When a task ends, Phew's own code saves the report at once: a PDF in the folder you chose, or in Downloads, and a Markdown copy in Phew's storage. The report waits in the menu until you open it on the card. The screen is not read again during the task. The one read stays in memory until the task ends or is stopped, then it is dropped.

How the Runner's rules are kept. The rules are in `03-experience.md` 3.6. Read the web search and web fetch pages of the Claude API documentation again before building.

| Rule | Kept by |
|---|---|
| Data, never instructions | The Runner has four tools: web search, web fetch, the Map search and `read_project_memory`, which only reads. None writes or changes anything, so a hidden instruction has nothing to act with |
| No web address from the screen, the Map or a file is opened | Phew's code removes web addresses from the screen text, the Map facts, each Map search result and file text before they are sent. The fetch tool's `url_sources` setting has `client_tool_results` set to none, so Anthropic's server never opens an address that came back from Phew's own tools. `user_input` is allowed, so an address you type in the task is opened (your decision of 14 November); the screen text and the Map facts in the first message have had their addresses removed by Phew's code before that. Read the exact setting names again in the documentation before building |
| Limits on searches, pages and cost | `max_uses` on web search and on web fetch, in every request. `max_uses` counts inside one request only, and a task takes several requests: one more after each Map search, and one more when Anthropic pauses a long turn. So Phew's code counts the searches and pages used in each reply and sends only what is left as `max_uses` in the next request. When none are left, that tool is left out of the request. Phew's code also adds up the cost after each reply and ends the loop at the limit. The check runs between replies, so the last reply can pass the cost limit by a little |
| Secrets | The secrets filter runs on everything Phew sends: the task, the screen text, the Map facts, each Map search result, each project file read |
| No writing | No file tool that writes. Phew's own code writes the PDF and its Markdown copy, under the rules in `03-experience.md` 3.6 |
| The screen once | One read, when the task is given. The Runner has no tool to look again |
| Several tasks, Stop | Phew's code runs up to 3 tasks at once (first proposal), each with its own counts, cost and screen read, and refuses a fourth. Stop on one task cancels its request within 2 seconds and drops what it read; the others go on |

Routes. The Conductor chooses one of four. The code has `explain`, `guide` and `remember` today. `task` is new in phase PA.

| Route | When | Who works |
|---|---|---|
| explain | You want to understand something. Also when you ask what he remembers: "what do you know about this project?". With nothing said, it is explain with no Conductor call | Guide, with the Map |
| guide | You want to know how to do something, where to click or which steps to take | Guide, then Follower |
| remember | You only tell him a fact, correct one, or say "forget that" | Librarian alone. The card shows one line that names what was stored or replaced. For a forget, he acts at once and the card names what went; it waits 30 days in Recently deleted. The rules, and what forgetting does, are in `05-map.md` |
| task | Work he does away from your screen: research, find sources, compare, collect | Runner |

Three tie-breaks:

- A request that is both a question and a fact ("the deadline is the 20th, what do I do first?") is a question. The Librarian picks up the fact after the answer, as it does after every answer.
- When the Conductor is unsure between task and explain, it chooses explain. An answer is quick. A task runs in the background and costs more. Approved 14 November.
- When the Conductor's reply cannot be read, the route is explain, as today.

Today the code sends "what do you remember?" to the remember route and answers it with one fixed line. From phase P5 that question goes to explain, and the fixed line goes away.

Keeping it cheap and quick in the MVP: small model for three of six agents, window text and one picture together on every call (the window under the mouse, or the whole screen when the mouse is not on the front window), one pixel per point, short context packets, streamed answers, cost and latency logged for every call. How similar tools do this is in `10-research.md` 10.2 and 10.4.

## 4.5 Backend, later

| Part | What it does | Service |
|---|---|---|
| Sign in | Accounts, sessions | Supabase Auth |
| Gateway | Holds the model keys, checks the user, applies limits | Supabase Edge Functions |
| Background jobs | Runner, Scribe, Keeper | Trigger.dev |
| Database | Users, the Map, events | Supabase Postgres |
| Vector search | Related memories by meaning | pgvector |
| Files | Transcripts, exports | Supabase Storage |
| Live updates | Eggs, dashboard refresh | Supabase Realtime |
| Website and dashboard | Landing, sign in, Map view | Next.js on Vercel |
| Errors and usage | Opt in | Sentry, PostHog |
| Payments | | Stripe |

Why Trigger.dev over Inngest: Phew's background work is agent runs that last minutes. Trigger.dev is built around long-running tasks on its own workers, with a simple task model and an open source licence. Inngest is stronger for many short event-driven steps, which is not Phew's shape. Not needed for the MVP.

Moving the Map into this database would change the rule "The Map lives only on the Mac". It needs your decision first.

How this backend gets made: you rent four managed pieces and connect them. A database with accounts, small functions that hold the secret keys, a jobs service, a website host. The coding agents write them from this file and `05-map.md`.

## 4.6 Privacy by design

- Phew reads only when called. During a guide he may watch the screen, only to know when it has settled and whether it changed. The watch starts when the guide's steps are shown. It stops as soon as he stops following: the last step is done, the card closes, you press Escape, the limit of 40 looks is reached, or a look fails. It also stops after 2 minutes without an action from you, and starts again when you act (approved 14 November). The watch itself sends nothing to the model: a look is still made only after you act. What he watches stays in memory and is never written to disk or to a log.
- Speech is transcribed on the Mac. The sound is held in memory only and dropped as soon as it is text. It is never saved and never sent.
- Password fields are never read. Secrets are removed before any network call.
- No Pause: it was removed on 14 November, and the shortcut always works. Instead, a "Never read this app" list in the menu bar. When the front app is on it, Phew reads nothing from it, for a call, a guide or a task, and says so in one line. The list holds app names only.
- In the MVP everything except the model call stays on your Mac. The Map is stored only on your Mac: no account, no sync, and Phew never uploads the file. The whole file is encrypted, and sensitive facts get a second lock; how is decided after the research task P5.13. Your own Time Machine backup, if you use one, copies it like any other file. To answer, Phew sends the Claude API your question, what is on screen, your short profile and the few remembered facts that match the question, after the secrets filter. A research task also sends search words to the web. In short: memory on your Mac, thinking in the cloud.
- What an agent reads from the web, a file or pasted text is treated as data, never as instructions.
- The project's `CLAUDE.md` and Claude Code memory files are read only when an import is started or a question or task needs them, never in the background, and pass the secrets filter.
- Imported memory from other AI tools is filtered for secrets, shown to you, and kept only if you tick it.
- What Phew captures (screen text, screenshots) is held in memory only. It is dropped when the answer is done or stopped, when a guide ends, and when a task ends or is stopped. It is never saved. A follow-up question takes a fresh look: only your earlier question and his answer are kept, as text, never the screen text or the picture of an earlier turn. The Map keeps what Phew learned, never the capture.
- A task keeps its one screen read in memory until the task ends or is stopped, then drops it. The app name, the window title and a file's path or page address are labels, not the capture: the Map may keep them. Both points are in the capture rule in `CLAUDE.md` since 14 November.
- A line in `calls.log` holds only the time, the agent, the model, token counts, cost, timings, how the call ended and a task number. The system log may also name an event with no words from you in it, such as the screen watch starting or stopping, or the one screen read of a task. No log, in any build, holds a question, a task's words, search words, web addresses, Map facts or an answer. This is the logging rule in `CLAUDE.md` since 14 November.
- macOS shows its own indicators for microphone and screen capture. Phew adds none.
- Before public release: privacy policy, terms, EU check, recording notice for lectures. Not legal advice.

## 4.7 Cost

- MVP: Claude API usage only. No Apple Developer Program, no hosting.
- Later: the services in 4.5 have free tiers. The Apple Developer Program is needed only to distribute.
