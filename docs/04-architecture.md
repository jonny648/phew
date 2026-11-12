# 4. Architecture

Two views. Section 4.1 is what the MVP builds. Sections 4.2 to 4.7 are the full target, so nothing built now has to be thrown away.

## 4.1 MVP architecture: everything on the Mac

One Swift app, one repository, no cloud of your own. The only outside call is to the Claude API.

```
PHEW.APP (Swift, on your Mac)
  Shell     menu bar item, input panel, pointer overlay, text card
  Senses    window text and positions, screenshot, speech to text, secrets filter
  Brain     Conductor, Observer, Guide, Librarian
            behind one interface, so it can move to a backend later
  Map       SQLite file: nodes, edges, events
  Keychain  your Claude API key
        |
        v
  Claude API   small model for Conductor, Observer, Librarian
               main model for Guide
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
| Local store | The Map and recent context | SQLite | Yes |
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
| Librarian | Reads from and writes to the Map | Small | Yes |
| Runner | Handed-off tasks such as research | Main | Later |
| Scribe | Lecture transcript to key points | Main | Later |
| Hand | Actions in other apps | Main | Later |
| Keeper | Nightly housekeeping of the Map | Small | Later |

Model provider: Claude API. Small means the Haiku class, main means the Sonnet class. The coding agent must read the current model names from the API documentation instead of guessing them.

Flow of one request:

1. You press the shortcut or hold the key and say "I don't get this".
2. Senses build the raw packet. Observer cleans it.
3. Librarian adds what the Map knows about this course and topic.
4. Conductor sends it to Guide.
5. Guide streams an explanation and steps, each tied to an element on screen.
6. The pointer shows them.
7. Librarian records what happened.

Keeping it cheap and quick in the MVP: small model for three of four agents, window text and one picture together on every call (the window under the mouse, or the whole screen when the mouse is not on the front window), one pixel per point, short context packets, streamed answers, cost and latency logged for every call. The wider question of how similar tools do this is a research item in the parking list.

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

How this backend gets made: you rent four managed pieces and connect them. A database with accounts, small functions that hold the secret keys, a jobs service, a website host. The coding agents write them from this file and `05-map.md`.

## 4.6 Privacy by design

- Phew reads only when called.
- Speech is transcribed on the Mac.
- Password fields are never read. Secrets are removed before any network call.
- A per-app exclusion list and one pause switch in the menu bar.
- In the MVP everything except the model call stays on your Mac.
- What Phew captures (screen text, screenshots) is held in memory only and dropped after the answer. It is never saved. The Map keeps what Phew learned, never the capture.
- macOS shows its own indicators for microphone and screen capture. Phew adds none.
- Before public release: privacy policy, terms, EU check, recording notice for lectures. Not legal advice.

## 4.7 Cost

- MVP: Claude API usage only. No Apple Developer Program, no hosting.
- Later: the services in 4.5 have free tiers. The Apple Developer Program is needed only to distribute.
