# 4. Architecture

Two views. Section 4.1 is what the MVP builds. Sections 4.2 to 4.7 are the full target, so nothing built now has to be thrown away.

## 4.1 MVP architecture: everything on the Mac

One Swift app, one repository, no cloud of your own. The only outside call is to the Claude API.

```
PHEW.APP (Swift, on your Mac)
  Shell     menu bar item, input panel, pointer overlay, text card
  Senses    window text and positions, screenshot, speech to text, secrets filter
  Brain     Conductor, Guide, Follower, Doer, Librarian, Runner
            behind one interface, so it can move to a backend later
  Map       SQLite file with text search. Stored only on the Mac
  Keychain  your Claude API key
        |
        v
  Claude API   small model for Conductor, Librarian
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
| Notch home | Character, states, eggs | Borderless panel placed around the notch | Later. Only the listening shape while you hold the key to talk is built (P6.4) |
| Input panel | A few typed words at the cursor | Non-activating panel | Yes |
| Pointer overlay | Second cursor, highlight, text card | Transparent full-screen window that ignores the mouse | Yes, simple |
| Window reader | Text, structure and position of elements | macOS Accessibility API | Yes |
| Screen capture | A picture with the text on every call | ScreenCaptureKit | Yes |
| Voice in | Speech to text on the device | Apple speech, or WhisperKit | Yes, last |
| Secrets filter | Removes keys, card numbers, password fields | Local rules | Yes |
| Local store | The Map: things, links and past questions. The last turns of a conversation stay in memory only | SQLite | Yes |
| Lecture capture | Microphone and system audio | AVFoundation, ScreenCaptureKit audio | Later |
| Hands | Press, set a value, pick a menu item, a single click, scripts | Accessibility actions, AppleScript, the system's calendar and reminders access (`13-hand.md`) | Yes, phase PH |
| Updates | Signed, notarised, automatic | Developer ID, Sparkle | Later |

Positions from the Accessibility API let Phew point at the exact button. When an app exposes nothing, the main model returns coordinates from the screenshot.

## 4.4 The brain: agents and roles

| Agent | Job | Model | MVP |
|---|---|---|---|
| Conductor | Understands the request, chooses who works | Small | Yes |
| Observer | Removed on 16 November 2026: it never ran, since the packet's text is capped at 4,000 characters | none | No |
| Guide | Explains and produces pointing steps. The main agent | Main, with vision | Yes |
| Follower | During a guide, looks at the screen after each action and says which step you are on, so the guide moves on by itself | Main, with vision. The small model missed steps done at once in testing | Yes |
| Librarian | Writes what was learned to the Map after each answer. Reading before an answer is done by Phew's own code, with no model call | Small | Yes |
| Runner | Researches a task alone: reads the screen once, the Map, the project's Claude Code files when needed, and the web, in a loop with limits, then reports. The Runner itself has no tool that writes. When the report is ready, Phew's own code saves it as a new PDF in the folder you chose or in Downloads, with a Markdown copy in Phew's own storage | Main, with web search and web fetch | Yes |
| Scribe | Lecture transcript to key points | Main | Later |
| Doer and Hand | Actions in other apps. The Doer is an agent: from your words, a fresh look and what was done so far, it gives the next single action. The Hand is Phew's own acting function in Senses and carries it out; it has no model, and its rules (the Never list, Stop, the brake) are code (`13-hand.md`) | Main model for the Doer | Yes, phase PH, built 15 November |
| Keeper | Nightly housekeeping of the Map | Small | Later |

Model provider: Claude API. Small means the Haiku class, main means the Sonnet class. The coding agent must read the current model names from the API documentation instead of guessing them.

Flow of one request:

1. You press the shortcut or hold the key and say "I don't get this".
2. Senses build the raw packet, with its text capped at 4,000 characters, and it goes on as it is. The Observer that once cleaned it was removed on 16 November 2026.
3. Phew's own code adds what the Map knows about this project and topic, and the last turns of the conversation as text. It is a text search, with no model call (see `05-map.md`). The Guide can also search the Map itself when it needs more.
4. Conductor sends it to Guide.
5. Guide streams an explanation and steps, each tied to an element on screen.
6. The pointer shows them.
7. After each thing you do, Follower looks at the fresh screen and moves the pointer to the step you are on. No Next button.
8. Librarian records what happened.

Following a guide faster (phase PS). The Guide marks each step that needs only a click. On such a step a direct hit on the marked target moves to the next step at once, with a "looking" motion on the pointer. The look then confirms, and a wrong advance steps back. A direct hit is a press and release without a drag, inside the marked element, or inside the ring (22 points) around a marked point. Steps that need typing, dragging or choosing wait for the look. So does the last step, so the card never closes on a guess. During a guide a screen watch tells Phew when the screen has settled. Its rules are in 4.6.

Flow of one task: you type or say a task. The Conductor chooses the task route. No consent screen is shown. The Runner gets your task and the one screen read made when you called him. It can search the Map with the same search tool the Guide has, and a task about a project you pointed him at gets a short excerpt of that project's `CLAUDE.md` in the request (see `05-map.md` 5.10). It then searches and reads the web until it can answer or reaches a limit. Up to 3 tasks run at once (first proposal), each with its own limits and its own Stop. A mark in the menu bar shows how many are working. When a task ends, Phew's own code saves the report at once: a PDF in the folder you chose, or in Downloads, and a Markdown copy in Phew's storage. The report waits in the menu until you open it on the card. The screen is not read again during the task. The one read stays in memory until the task ends or is stopped, then it is dropped.

How the Runner's rules are kept. The rules are in `03-experience.md` 3.6. The table shows the Runner as built for research: it writes nothing itself. Since 15 November an agent may also act in the background, only through the apps' own scripting and the system's calendar and reminders access (`13-hand.md` 13.4 and guard 12). That is added in phase PA and goes through Phew's one acting function. Read the web search and web fetch pages of the Claude API documentation again before building.

| Rule | Kept by |
|---|---|
| Data, never instructions | The Runner has four tools: web search, web fetch, the Map search and `add_item`. The first three only read. `add_item` only adds a new note, reminder, event or sheet, through Phew's one acting function; it cannot send, delete or replace, so a hidden instruction has little to act with |
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

Keeping it cheap and quick in the MVP: small model for three of six agents, window text and one picture together on every call (the window under the mouse, or the whole screen when the mouse is not on the front window), one pixel per point, short context packets, streamed answers, cost and latency logged for every call. How similar tools do this is in `10-research-agents.md` 10.2 and `10-research-speed.md` 10.4.

### Speed and cost, measured (phase PS, 15 November)

All numbers come from live calls on made-up data: a full display picture (1512×982), the most text and elements a packet holds, a made-up Map. Cents include every call of the question, its Librarian too.

**Target for a plain question with the Map (PS.12):** the first word within 3 s on average, and at most 1.5 cents a question. Met over 10 questions: 2.7 s on average (slowest 3.3 s), 1.3 cents.

| Measured | Before | After | What changed |
|---|---|---|---|
| Wait before the Guide starts | 3.2 s | 1.1 s | Only the Conductor is waited for now |
| Observer | 2.0 to 3.1 s, all before the Guide | Skipped | It cut 4,000 characters to about 1,300 and saved the Guide about 0.14 cents. It then ran only on text longer than the packet's cap, so never; its code was removed on 16 November 2026 |
| Wait for the last Librarian | Up to 1.1 s here, 3.2 s on 14 November | None | The next answer reads the Map as it is. Remember and forget still wait for it |
| First word | 4.9 s | 2.7 s | |
| Text the Guide reads | 8,000 to 9,000 tokens, all at full price | 4,000 to 5,100 new, 3,226 from the cache | An explanation no longer gets the list of elements; the fixed part is cached |
| Cost a question | 2.1 cents | 1.3 cents | |
| "What did I do this month?", the search round | 1 of 2 runs searched twice; 2.0 and 2.9 cents | 3 of 3 runs searched once; 0.75 cents | After a result that says it is complete, the code makes the next round answer. The Map rules moved to the end of the Guide's instructions |

The search round itself stays (1.5 to 1.9 s): that question needs it. The cache lives 5 minutes, so the first question after a quiet spell pays to write it, about 0.8 cents more.

**A reply in a conversation (PS.13).** The fixed part (the Map search tool and the Guide's instructions) and the earlier turns are cached. In a conversation of 4 replies the Guide read 0, 3,226, 3,576 and 3,812 tokens from the cache. A reply costs about 1.2 to 1.3 cents from the second reply on; the first costs 1.9 cents because it writes the cache. Without the cache a later reply would cost 0.6 to 0.7 cents more.

**A look while following a guide (PS.4).** A look sends the picture cut to 800×600 around the mouse, at most 30 elements (those the remaining steps name, then the nearest to the mouse) and the first 1,000 characters of text; the instructions and the steps are cached. Over 10 looks: 1,885 new and 876 cached tokens, 0.41 cents a look, 10 of 10 right; the first look of a guide costs about 0.2 cents more, as it writes the cache. Before: 6,419 tokens and 1.31 cents a look. A dialog far from the mouse is seen only in the text and the elements.

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
