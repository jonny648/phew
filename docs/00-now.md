# Where Phew is now

Updated on 16 November 2026. One page. The details are in the docs linked at the end.

## What Phew does today

Built through the last MVP phase (PG): version 0.1.0. Not every part was tried on real work; see "Where the build is" below.

- He lives in the menu bar. No main window, no Dock icon.
- You call him with a shortcut and type a question.
- He reads the screen only when you call him. Apps on your "Never read this app" list are never read.
- He explains what is on screen in a card, and the card is a conversation: click it and reply.
- He guides you step by step by pointing on the screen, and follows what you do. You do not press Next.
- He remembers your projects in the Map. The Map is two encrypted files on your Mac. It is never uploaded. Only the few facts an answer needs go with your question.
- He knows which project you are in, from the open file, web address or window.
- You can ask what he remembers, tell him a fact, correct one, or say "forget that". A forgotten fact waits 30 days in Recently deleted.
- You can export the Map to one readable Markdown file.
- He knows himself: what he is, what he can and cannot do.
- A question costs about 1.3 cents; the first word comes in about 3 seconds.

Also built, and described below: acting in your apps (PH), agents that research a task alone and add things in the background (PA), importing memory from other AI tools (PB), voice (P6).

## Closed on 15 November

- **PS Conversation and speed**: the conversation card, the faster guide, faster answers with the Map.
- **PD Direction and revision**: one specific job chosen, validated by desk research, the roadmap rewritten, the competitor map in Figma updated.

## The direction, set on 15 November

Phew is a collaboration companion for people who create projects. He works with you and does the jobs you ask for, acting on the Mac by himself. He also explains and guides, remembers your projects, and researches. Business software training is a separate product, later. See `02-vision.md` and `07-decisions.md` 7.1.

## Where the build is

**PH Hand and look, PA Agents and PL Live checks are done**, on 15 November. He acts in your apps from your words, with nothing to allow; several apps in one job; the new look on every surface. He researches a task alone, up to three at once, saves a PDF report, and adds notes, reminders, events and sheets in the background.

Proven live on made-up data: acting in a practice window, clicking on a canvas, switching app and coming back, the scripting of Notes, Reminders, Calendar and Excel, a real research task, three at once with Stop, and two trick tests where no hidden text made him do something else.

**Known to be weak, kept for after the MVP (L18):** acting in Dia, Figma and Fusion was never tried; changing, sending and deleting are not built; the research limits were never reached in a live run.

## Closed on 15 November: PB Second brain

Under Memory in the menu: paste a memory list from Claude, ChatGPT or Gemini and tick what he keeps; import from a project folder (only its `CLAUDE.md` and its Claude Code memory files); undo last import. Verified by the checker on made-up data. Not seen on a real screen yet: the folder window and the panel in use.

## The MVP is built: version 0.1.0, 16 November 2026

Online, private: https://github.com/jonny648/phew. The installer is `Phew-0.1.0.dmg`, on the release page and in `~/Downloads/Phew-release/`.

Voice is in: hold the shortcut and speak, on the Mac, with feedback at the notch. Every MVP task in the roadmap is ticked; several were ticked on your word before a run, and their lines say so.

## Next

Use it on real work and note each failure. The next phases are in `../roadmap-next.html`. Then L18 (acting and agents, second pass, and misheard names), then a notarised app for ten people. The retro is in `07-decisions.md` 7.6.

## Decisions waiting for you

- **Which of the cheap tests of the validation to run** (decision 40).
- **The first user group, the cost of 10 users, what success means for you** (decision 41, `14-company.md` 14.6).
- Which business target to explore first, if any (26). Order of the later phases (27).

Taken by the written recommendation on 15 November, say if you want another: 40 actions per job and 20 per minute as a runaway brake (39); "Fusion" is Autodesk Fusion (37).

The open decisions are listed in `07-decisions.md` 7.2.

## Main docs

- `README.md` in this folder: every doc, with what it is for.
- `../roadmap.html`: the checklist of every phase.
- `11-direction.md` and `12-validation.md`: the direction research and its validation.
- `13-hand.md`: how Phew acts on the Mac.
- `07-decisions.md`: your decisions and the session log.
- `03-experience.md`: what you see and do.
- `05-map.md` and `05-map-storage.md`: the Map.
