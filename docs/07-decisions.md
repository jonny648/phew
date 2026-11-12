# 7. Decisions

## 7.1 Taken

| Date | Decision | By |
|---|---|---|
| 10 Nov 2026 | Name and character: Phew!, black chick with eggshell | You |
| 10 Nov 2026 | Main feature: explain and guide. Everything else underneath | You |
| 10 Nov 2026 | No selection logic. Not built on InlineRewriter | You |
| 10 Nov 2026 | No "what it saw". Privacy by design, not by display | You |
| 10 Nov 2026 | Multi-model, multi-agent | You |
| 10 Nov 2026 | He listens and does not talk | You |
| 10 Nov 2026 | Validation skipped | You |
| 11 Nov 2026 | Deadline 24 November, hours vary | You |
| 11 Nov 2026 | Sprint ends at an MVP that solves the main problem. Graphics and other features later | You |
| 11 Nov 2026 | Model provider: Claude API for now | You |
| 11 Nov 2026 | No Apple Developer Program now. Not published | You |
| 11 Nov 2026 | Lecture consent is not a concern for personal use. A recording notice like Granola's when public | You |
| 11 Nov 2026 | Jobs service: Trigger.dev, when background agents are built | Delegated to Claude |
| 11 Nov 2026 | MVP runs fully on the Mac. Backend after the MVP | Proposed. Confirm |
| 11 Nov 2026 | Native Swift app, one repository | Proposed. Confirm |
| 11 Nov 2026 | Map in SQLite for the MVP, same shape as the later Postgres | Proposed. Confirm |
| 11 Nov 2026 | Product stays student-first for the build. Business targets researched in `08-b2b-targets.md` | You |
| 11 Nov 2026 | Shortcut: Right Option + Right Command together opens the input panel | You |
| 11 Nov 2026 | Hold key for speech: Right Option held alone. Built in P6 | You |
| 11 Nov 2026 | App Sandbox off, so Phew can read other apps' windows. Bundle id `com.gianlucatroietto.Phew` | Delegated to Claude |
| 12 Nov 2026 | Test apps for screen reading in P2: Dia, Figma, Keynote, Notion, Finder, Apple Notes. InDesign and Acrobat move to the new phase PT Manual testing | You |
| 12 Nov 2026 | Claude Code roles: builders (shell, senses, brain, map) on Opus, checker on Sonnet | You |
| 12 Nov 2026 | Captures (screen text, screenshots) are never saved. Memory only, dropped after the answer. Debug dump only with a test flag | You |
| 12 Nov 2026 | Acting in apps (L5 Hand) will be a separate opt-in, off by default. Without it Phew only shows and explains. After the MVP | You |
| 12 Nov 2026 | Pointing from screenshot coordinates is never cut: Figma and Figma Slides are the main apps and expose no text | You |
| 12 Nov 2026 | "Full reading" switch stays on in native apps. Needed for Keynote slides, no lag seen | You |
| 12 Nov 2026 | `docs/review/plan.html` removed. The Markdown files and `roadmap.html` are the source | Delegated to Claude |
| 12 Nov 2026 | A picture goes with the text on every question. The whole display when you point outside the front window | You |
| 12 Nov 2026 | The guide follows what you do by itself. No Next button. Phew may look at the screen again during a guide, after you act. Built in P4 as P4.7 | You |
| 12 Nov 2026 | Direction widens from a student helper to a general, professional tool, partly in the MVP. The new phase PR Research and review decides how. Product line and hard rules stay as written until PR.1 | You |
| 12 Nov 2026 | Deadline stays 24 November. PR decides the scope, with that date as the aim | You |

## 7.2 Open

| # | Decision | Needed by |
|---|---|---|
| 2 | Per-app exclusion list ("never read this app"), promised in `04-architecture.md` 4.6: in the MVP or later? Pause is the only switch today | P6 |
| 3 | Which business target to explore first, if any | After the MVP |
| 4 | Order of the later phases | Retro |

## 7.3 Parking list

- **Research: what similar tools use for agents.** Which models and agent frameworks Clicky and comparable tools run on, and how they keep calls cheap and fast: model routing, caching, small models, on-device steps. Do this before the backend phase.
- **Students bring their own AI subscription.** Claude Pro and Max cannot be used: Anthropic forbids subscription sign-in in third-party apps, so Claude needs an API key. ChatGPT Plus and Pro may be possible through "Sign in with ChatGPT" (autumn 2026, partner apps); check OpenAI's own documentation on who can join. Would remove Phew's model cost per student. Needs a second provider behind the provider interface. Revisit at the retro.
- **Tool connections (MCP).** Phew reads a project through the tool's own connection, for Figma, Notion and others, not only through the screen. Decided in PR.4.
- **Independent work.** Phew edits things locally and runs agents by himself (L3, L5). Decided in PR.5.
- **Follow-up questions.** Today each question starts from zero. Input to PR.3.
- **The card can cover a guide's target.** Move it out of the way if it bothers you.
- Open source as a route for the student version.
- Other devices.
- Sharing a course Map between classmates.

## 7.4 Log

| Date | Phase | What happened | Next |
|---|---|---|---|
| 11 Nov 2026 | P0 | Project moved to the root, Xcode project created, signed with the personal team. P0.1, P0.2, P0.4, P0.5 ticked | P1 |
| 12 Nov 2026 | P1 | Shell built: menu bar item, shortcut, input panel, permissions screen. Focus bug on second open fixed. P0.3, P1.1, P1.2, P1.5, P1.6 ticked | Your re-test of P1.3 (3 apps) and P1.4 (type without clicking) |
| 12 Nov 2026 | P1 | Your re-test passed in Finder, Dia and WhatsApp. P1.3 and P1.4 ticked, P1 complete. Role models set, test apps chosen | P2 |
| 12 Nov 2026 | P2 | Senses built and hand-tested in Dia, Figma, Finder, Keynote, Notion. Three weaknesses found: no screenshot in Figma, empty element under the cursor, Keynote slide text not read. Phase PT added to the roadmap | Fixes, your re-check in Figma and Keynote, then ticks |
| 12 Nov 2026 | P2 | Fixes passed your re-check in Keynote and Figma. Fresh captures in Dia and Apple Notes. P2.1 to P2.5 ticked, P2 complete. Captures made memory-only, docs brought up to date | P3 Brain |
| 12 Nov 2026 | P3 | Brain built and hand-tested with your key in Dia, Figma and Notion. Live self-check 18 of 18. P3.1 to P3.8 ticked. About 0.9 cents and 2.5 to 4.5 s to the first word per question. Found: no picture sent outside the front window (wallpaper question failed). P3.9 and P4.6 added | P3.9 Phew always sees, then P4 Pointer |
| 12 Nov 2026 | P4 | P3.9 built: a picture with every question. P4 Pointer built: overlay, pointer, step-by-step guide, card no longer takes the keyboard. Your hand test passed on every point. Your review asked for a guide that follows you, tool connections, deeper understanding and a professional direction. P4.7 and phase PR added | P4.7 the guide follows you, then PR |

## 7.5 Your review of 12 November. Input to phase PR

In your words, shortened:

1. **Interactive steps.** If I do the step myself, for example change a sticky note's colour in Figma without clicking Next, the guide should continue by itself, reviewing what I do. Remove the Next and Continue buttons. Not intrusive, no extra things for the user to do. (Built as P4.7.)
2. **Connections.** MCP connections and project management across tools: connect Phew directly to a project or file in Figma or any other app.
3. **Independent work.** Today the tool is only useful for asking something specific. It needs logic for independent work that can edit locally: AI agents, editing things, deep project understanding.
4. **Usability and logic.** Usability is the main part, reached through UI and UX. The logic matters too: today it understands small specific things and does not feel like a tool to use when needed.
5. **Vision.** A way to use AI tools and models away from their own platforms, with a very interactive, easy interface.
6. **Deep understanding.** Improve the Map and the logic, and maybe other things not yet known.
7. **From student to general.** Not small tasks on projects, but understanding what the user is doing, why, and how to do what they ask. A professional tool, partly reached in the MVP.

Rules this touches, unchanged until PR.1: "Explain and guide is the only visible feature", "Nothing from the Later section of the roadmap is built during the MVP", and the product line "for university students".
