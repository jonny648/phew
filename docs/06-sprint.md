# 6. Sprint and roadmap

Deadline: Tuesday 24 November 2026. Hours vary, so the plan is by phase, not by day. The live checklist is `roadmap.html` in the project root.

## 6.1 What the sprint delivers

**The MVP.** On your Mac, Phew explains and guides on real coursework, in the apps you use, and remembers the course so you never re-explain. That is the main problem solved at its minimum.

Not in the sprint: notch and character, backend, dashboard, background agents, lecture listening, actions in other apps, wake word, anything for publishing.

## 6.2 Phases

| Phase | Target dates | Goal | Subagent |
|---|---|---|---|
| P0 Setup | 11 Nov | Repository and an empty app that builds | lead |
| P1 Shell | 12 to 13 Nov | Menu bar, shortcut, input panel, permissions | shell |
| P2 Senses | 14 to 15 Nov | Window text, positions, screenshot, secrets filter | senses |
| P3 Brain | 16 to 17 Nov | Claude API, Conductor, Observer, Guide, text card | brain |
| P4 Pointer | 18 to 19 Nov | Phew points and guides step by step | shell |
| PR Research and review | 13 to 14 Nov | Your review of 12 Nov answered: product restated, MVP re-scoped. No code. May change every phase below | lead |
| P5 Map | 20 to 22 Nov | Memory of courses and topics, read and write | map |
| PT Manual testing | Before the MVP test | Checks only you can run: InDesign, Acrobat, and others that come up | checker |
| P6 Voice and test | 23 to 24 Nov | Hold key and speak. MVP test on real coursework | senses, checker |
| PG GitHub and project structure | 24 Nov, after the MVP test | Folder brought to the usual standard, private repository pushed, version 0.1.0 tagged | lead, checker |

Tasks and their "done when" are in `roadmap.html`.

## 6.3 MVP is done when

1. Over 2 days of real coursework, 8 of 10 questions get a useful explanation or guide.
2. It works in at least 3 apps you use.
3. A second question on a topic uses the first, with nothing re-explained.

## 6.4 If time runs short

Cut in this order: voice, defined terms in the Map. Never cut: explain and guide, the pointer on Accessibility positions, pointing from screenshot coordinates (the only way to point inside Figma and Figma Slides), Map read and write.

P1 and P2 can be built in parallel. So can P4 and P5.

## 6.5 How to manage it

- **Roadmap first.** Every Claude Code session starts by reading `roadmap.html` and ends by updating it. Rules in `CLAUDE.md`.
- **One phase at a time** per terminal.
- **A task is ticked only when verified**, by the checker subagent, by building and running.
- **Use Phew daily from P3.** Bugs found by use come before new tasks.
- **New ideas** go to the parking list in `07-decisions.md`.

## 6.6 After the MVP

Order to confirm at the retro. Unscheduled.

| Phase | Content |
|---|---|
| L1 Character | Notch home, states, animations, brand sheet |
| L2 Backend | Supabase: accounts, Map in Postgres, gateway, sync |
| L3 Background agents | Trigger.dev, Runner, Keeper, eggs in the UI |
| L4 Lectures | Capture, transcript, Scribe, recording notice |
| L5 Hand | Actions in other apps |
| L6 Dashboard | Website, Map view |
| L7 Wake word | His name, matched loosely |
| L8 Public | Apple Developer Program, signing, legal, pricing, first business pilot |
