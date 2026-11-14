# 6. Sprint and roadmap

No fixed deadline since 13 November 2026. The first aim was 24 November; you removed it so that nothing in the MVP is skipped. The plan is by phase, in order. The live checklist is `roadmap.html` in the project root.

## 6.1 What the MVP delivers

**Version 1.** On your Mac, Phew explains and guides in the apps you use, remembers your projects so you never re-explain, learns what your other AI tools already know about you, follows a guide without lag, takes speech, and researches a task by himself.

Not in the MVP: notch and character, backend, dashboard, connections to other tools, editing existing files, actions in other apps, lecture listening, wake word, anything for publishing.

## 6.2 Phases

| Order | Phase | Goal | Subagent | State |
|---|---|---|---|---|
| | P0 Setup | Repository and an empty app that builds | lead | Done 11 Nov |
| | P1 Shell | Menu bar, shortcut, input panel, permissions | shell | Done 12 Nov |
| | P2 Senses | Window text, positions, screenshot, secrets filter | senses | Done 12 Nov |
| | P3 Brain | Claude API, Conductor, Observer, Guide, text card | brain | Done 12 Nov |
| | P4 Pointer | Phew points and guides step by step, following you | shell | Done 13 Nov |
| | PR Research and review | Product restated, market and tools researched, MVP re-scoped. No code | lead | Written 13 to 14 Nov. Ticked at the end of PV |
| | PV Your review | You read everything on one page, understand it, and answer the open decisions. No code | lead, checker | Answered and approved 14 Nov |
| 1 | P5 Map | Memory of your projects, recall at any time, follow-up questions. Starts with research on encrypting the Map. Recently deleted | map, brain, senses, shell | |
| 2 | PB Second brain | Memory imported from your other AI tools, by paste and from Claude Code files. Claude Code files also read when an answer needs them | map, shell, brain | |
| 3 | PS Guide speed | The guide stops feeling slow, and costs half. Pause removed, "Never read this app" list | shell, senses, brain | |
| 4 | PA Agents | He researches tasks alone, several at once, and reports. Reports saved as PDF | brain, shell | |
| 5 | P6 Voice | Hold key and speak, in Italian and English | senses | |
| 6 | PT Manual testing | Checks only you can run: InDesign, Acrobat, Figma Slides | checker | |
| 7 | PM MVP test | Version 1 on real work | checker | |
| 8 | PG GitHub and project structure | Folder to the usual standard, private repository pushed, version 0.1.0 tagged | lead, checker | |

Rough size, an estimate and not a promise: Map 5 days with the encryption research and Recently deleted, second brain 2, guide speed 2, agents 8 to 12 with several tasks and PDF reports, voice 2, tests 2.5, GitHub 1. About 22 to 27 working days. Re-estimated on 14 November after your answers added work. The agents figure starts from the research estimate in `10-research.md` 10.2, 4 to 7 days to read and research and 2 to 3 more to save reports as files, plus about 2 for several tasks at once and PDF reports.

Tasks and their "done when" are in `roadmap.html`.

## 6.3 MVP is done when

1. Over 2 days of real work, 8 of 10 questions get a useful explanation or guide.
2. It works in at least 3 apps you use.
3. A second question on a topic, asked on a later day, uses the first, with nothing re-explained, and he knows your projects.
4. Of 3 real research tasks, 2 reports are useful.

## 6.4 Nothing is cut

By your decision of 13 November, no task is skipped or moved to a later version to save time. If a task proves wrong or impossible, it is brought to you, not dropped.

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
| L2 Backend | Supabase: accounts, Map in Postgres, gateway, sync. Moving the Map off the Mac changes a rule and needs your decision first |
| L3 Background agents | Scheduled and server-side agents, Keeper, eggs in the UI |
| L4 Lectures | Capture, transcript, Scribe, recording notice |
| L5 Hand | Actions in other apps, editing existing files |
| L6 Dashboard | Website, Map view |
| L7 Wake word | His name, matched loosely |
| L8 Public | Apple Developer Program, signing, legal, pricing, first business pilot |
| L9 Connections | Figma, Notion and other tools (MCP). Your own AI subscription |
| L10 Changing links | Links whose meaning changes with the matter or the setting. Research first |
| L11 Map in the cloud too | On the Mac and on a personal page of the website, divided by matter. Changes the rule "The Map lives only on the Mac" |
| L12 Usage limits | A rate limit for usage, then every limit written into the code |
| L13 Getting to know you | A short interview at install, and asking you when he cannot understand. Research first |
| L14 Reports that teach the Map | Research findings become connected facts, web findings after an internal review |
