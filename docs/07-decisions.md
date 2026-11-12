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
| 12 Nov 2026 | Test apps for screen reading in P2: Dia, Figma, Keynote, Notion, Finder, Terminal. InDesign and Acrobat move to the new phase PT Manual testing | You |
| 12 Nov 2026 | Claude Code roles: builders (shell, senses, brain, map) on Opus, checker on Sonnet | You |

## 7.2 Open

| # | Decision | Needed by |
|---|---|---|
| 2 | Keep the "full reading" switch Phew turns on in native apps (needed for Keynote slides)? It can make window moves lag in that app until it quits | End of P2 |
| 3 | Which business target to explore first, if any | After the MVP |
| 4 | Order of the later phases | Retro |

## 7.3 Parking list

- **Research: what similar tools use for agents.** Which models and agent frameworks Clicky and comparable tools run on, and how they keep calls cheap and fast: model routing, caching, small models, on-device steps. Do this before the backend phase.
- **Students bring their own AI subscription.** Claude Pro and Max cannot be used: Anthropic forbids subscription sign-in in third-party apps, so Claude needs an API key. ChatGPT Plus and Pro may be possible through "Sign in with ChatGPT" (autumn 2026, partner apps); check OpenAI's own documentation on who can join. Would remove Phew's model cost per student. Needs a second provider behind the provider interface. Revisit at the retro.
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
