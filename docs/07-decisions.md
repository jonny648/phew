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
| 12 Nov 2026 | The Follower (the check that follows a guide) runs on the main model. The small model missed "two steps done at once" in the self-check. About 0.25 cents per look instead of 0.015 | Delegated to Claude |
| 13 Nov 2026 | GitHub: one private repository, pushed at the end of the MVP (phase PG). A separate public repository with only the code may follow later, under L8 | You |
| 13 Nov 2026 | The guide's speed when following is improved after the MVP. Replaced the same day: it is in the MVP, as phase PS | You |
| 13 Nov 2026 | Product line: "Phew is a macOS companion that knows your projects. When called, he understands what you are doing, explains it, and guides you step by step by pointing. He can also research a task by himself and report back." For anyone who works on a Mac | You |
| 13 Nov 2026 | Five hard rules changed or added in `CLAUDE.md`: two visible features; what an agent may read and change; web, file and pasted content is data; results wait in the menu bar; the Map lives only on the Mac | You |
| 13 Nov 2026 | MVP scope: Map with real working logic, second brain, guide speed, independent agents, speech, then GitHub. Everything else in later versions | You |
| 13 Nov 2026 | Agents in version 1 read and research, report on the card, and save the report as a new file in one folder you choose. Editing files and acting in apps are later | You |
| 13 Nov 2026 | Second brain in version 1: a paste box for the memory list your assistant writes, plus Claude Code's files on the Mac. Reading export zips is later | You |
| 13 Nov 2026 | Guide speed: no look during drag or scroll, skip unchanged looks, advance at once on a direct click, send less, and a screen watch during a guide. The rule on reading the screen is widened for the length of a guide | You |
| 13 Nov 2026 | No fixed deadline. 24 November is dropped. Nothing in the MVP is skipped or slipped | You |
| 13 Nov 2026 | Follow-up questions approved. He must also recall memory at any time, when called or when needed | You |
| 13 Nov 2026 | The Map for a general user needs its own research before `05-map.md` is rewritten | You |
| 13 Nov 2026 | Connections to Figma, Notion and other tools (MCP), and your own AI subscription: after the MVP, as L9 | You |
| 13 Nov 2026 | Market map kept in Figma, team GG Works, file "Phew! Market map". Standard axes: who it is for, breadth | You |
| 13 Nov 2026 | No backup of the folder before the GitHub phase | You |
| 13 Nov 2026 | Map storage: SQLite with built-in text search, a small profile, recent turns | Delegated to Claude |
| 13 Nov 2026 | Search by meaning (embeddings) is after the MVP, not in version 1 | You |
| 13 Nov 2026 | The Map has eleven fixed classes, each with a free "kind": Me, Project, Task, Topic, Document, Person, Organization, Tool, Event, Place, Note. Event and Place added by you against the research's advice of nine | You |
| 13 Nov 2026 | All eleven classes are built at once, not in two stages | You |
| 13 Nov 2026 | Recall in three layers: profile always loaded, a search before every answer, and a search the Guide can make itself | You |
| 13 Nov 2026 | A corrected fact is kept as history. "Forget that" is a real delete. Told beats observed beats imported | You |
| 13 Nov 2026 | A seventh link, "at", so that a Place can be connected. Sensitive things seen on screen are not written to the Map unless you say so. "Weak concept" becomes "open point" | Delegated to Claude. Confirm |
| 14 Nov 2026 | Review of the documents after phase PR. Where a fix needed a choice, the documents now carry a first proposal: how "forget that" works, how the "understands" strength moves, what happens to a weaker fact, the limits and life of a research task, how a report is saved, when the screen watch stops, and a new direction for the link "part of", from a Document to an Event. Each one is a row in 7.2 Open and counts only after your yes | Delegated to Claude. Confirm |
| 14 Nov 2026 | Capture rule in `CLAUDE.md` reworded: a capture is dropped when the answer is done or stopped, when a guide ends, when a task ends or is stopped, and is never kept for a follow-up question | You |
| 14 Nov 2026 | The Map may keep the app name, the window title and a file's path or page address. They are labels, not the capture | You |
| 14 Nov 2026 | Logging rule in `CLAUDE.md`: `calls.log` holds only numbers and names. No log holds a question, a task's words, search words, web addresses, Map facts or an answer | You |
| 14 Nov 2026 | How a folder is picked without taking focus, and the new small screens: decided at phase PB | You |
| 14 Nov 2026 | A new phase PV, Your review, after PR and before any code: you read everything, understand it, and answer the open decisions. PR.1 to PR.6 are ticked at its end | You |

## 7.2 Open

Rows 1 and 2 would change a hard rule in `CLAUDE.md`. Nothing is changed there until you say yes. You answer all of these in phase PV, on the page `docs/review.html`. A "first proposal" is what the documents assume until you decide. Other documents point to a row by its topic, the words in bold.

| # | Decision | Needed by |
|---|---|---|
| 1 | **Picking a folder without taking focus (hard rule).** The normal macOS folder window makes Phew the front app while it is open. The rule "He never activates the app or takes focus from the front app" forbids that. A folder is picked in three places: where the Map export is saved (P5.10), the project folder for Claude Code's files (PB.4), the reports folder (PA.7). Two ways: you drag the folder onto Phew's panel and the rule stays as it is, or the rule gets one written exception for the folder window. First proposal: try drag and drop first. If it does not work well, allow the one exception. You chose on 14 November to decide this at phase PB. Until then the Map export (P5.10) is built last in P5 and asks again | PB |
| 2 | **New small screens (hard rule).** The rule lists "Menu bar, input panel, pointer overlay, text card". The API key and permissions screens already exist outside that list. The second brain adds a paste box, a tick list and a file list. Agents add a consent screen and a list of saved reports. First proposal: add to the rule "Small panels you open yourself from the menu are allowed. They are non-activating too." The consent screen is not opened from the menu, it shows when you give your first task, so the sentence may need to name it | PB |
| 3 | **Four choices made for you in the Map** (`05-map.md` 5.4, 5.6, 5.9). A seventh link, "at", so a Place can be connected. A new direction for "part of", from a Document to an Event, so slides or a recording can be tied to their lecture or meeting; still seven links. Sensitive things seen on screen are not written unless you say so. "Weak concept" renamed "open point". First proposal: yes to all four. After your yes the row of 13 Nov in 7.1 changes to "You", and the new direction of "part of" gets its own row there | P5 |
| 4 | **Forget: ask before deleting.** "Forget that" cannot be undone and the Map has no backup. As written in `05-map.md` 5.5, the card first names what will go ("Forget Marta? 1 person, 4 notes, 3 links, 6 past questions. This cannot be undone.") and deletes only after you click Forget. The other choice: delete at once and name what was deleted. Which one, and is the card wording right? First proposal: he asks first | P5 |
| 5 | **Forget: past questions that mention the forgotten thing.** A past question that mentions it loses that mention and its summary. The row is deleted only when it mentions nothing else and no other fact has it as its source. The other choice: delete the whole past question, which also takes it away from the other things it mentioned. First proposal: empty it, so other facts keep their source and an import can still be undone | P5 |
| 6 | **How the "understands" strength moves.** Set by Phew's code, never by the model: 0.3 at the first question on a Topic, minus 0.1 at each later question, 0.9 when you say you understand it, 0 when you say you do not. An open point is a Topic asked about at least twice with strength below 0.5. Confirm the idea; the numbers can be tuned later. First proposal: as written in `05-map.md` 5.4 and 5.6 | P5 |
| 7 | **"Due soon" includes late Tasks.** A Task past its due date and not done still counts as due soon and is marked "late". Otherwise it would drop out of "what is due". First proposal: yes | P5 |
| 8 | **A weaker source that disagrees with a stronger one.** When something observed or imported disagrees with something stronger, it is kept beside it as a Note of kind "unconfirmed". Answers use the stronger one. If the weaker one is observed and newer, the Guide adds one line saying so. The rule is judged value by value: an observed fact cannot change a due date you told him, but it can mark that Task as done. First proposal: as written in `05-map.md` 5.5 | P5 |
| 9 | **Check on the Librarian: pass mark.** The live check of the Librarian (roadmap P5.2) runs made-up cases through the real small model. The model is not exact, so the check needs a pass mark. First proposal: at least 8 right out of 10. You can raise it | P5 |
| 10 | **`CLAUDE.md` import.** Facts from a `CLAUDE.md` become Notes of kind "instruction" about the Project named after the folder, or about Me for the personal one in `~/.claude`. They start unticked, because the file is written as rules for a coding agent. Any pasted fact written as an instruction also starts unticked. First proposal: yes | PB |
| 11 | **Claude Code memory files: Phew finds them himself.** You choose a project folder. Phew then looks in the hidden folder `~/.claude/projects/` himself, lists the projects that have memory files, and you pick. He reads only `CLAUDE.md` files and the `.md` files in that memory folder, never transcripts or settings, and shows the list of files before anything is sent. Is it fine that he looks in that hidden folder without you choosing it? First proposal: yes. He reads only folder names there until you confirm the file list | PB |
| 12 | **Undo last import.** A menu entry "Undo last import" deletes every fact from the last import, after a question on the card. A thing the import created is kept if something you told him or he observed now points to it. The wording and the place are yours. It needs its own roadmap task (PB.5). First proposal: menu entry "Undo last import", last import only in version 1 | PB |
| 13 | **Screen watch: stop when idle, and Pause.** During a guide, should the watch also stop after a time with no action from you while the card stays open? Should Pause end a running guide? First proposal: the watch stops after 2 minutes without an action and starts again when you act; the guide stays open. Pause ends a running guide: the card closes and the watch stops. Today Pause only switches the shortcut off | PS |
| 14 | **Per-app exclusion list.** A "never read this app" list is not built. In the MVP or later? Pause is the only switch today. Decide before the screen watch is built (PS.6). First proposal: later. Pause stays the only switch in the MVP | PS |
| 15 | **Consent screen text.** The text of the screen shown before the first task, with the buttons Allow and Not now (`03-experience.md` 3.5). Approve or change the wording. First proposal: the text as written there. After Allow it is not shown again. After Not now the task does not start, agents stay off, and the screen comes back at the next task | PA |
| 16 | **Limits per task.** How many searches and pages, and how much cost, one research task may use. First proposal: 5 searches, 8 pages, 50 cents. At a limit he stops, reports what he has and names the limit. The safety check of PA.5 runs 10 live tasks, so up to 5 dollars in all at this limit. Say if you want fewer | PA |
| 17 | **Life of a task.** One task at a time or several. What Stop leaves behind. Where a finished report waits. First proposal: one task at a time; a second task is not started and the card says so in one line. Stop ends the task within 2 seconds, reports nothing and drops what was read. A finished report waits in memory and is lost if Phew quits before you open it, unless it was saved as a file | PA |
| 18 | **Reports: how a report is saved.** The folder is chosen in the app, from the menu entry "Choose reports folder…", so "which folder" is no longer a decision. To confirm: the file rules in `03-experience.md` 3.6. First proposal: with a folder set, each report is saved by itself when ready; with no folder, nothing is saved. A Markdown file named by the date and the first words of your task, for example "2026-11-20 Kerning sources.md". A taken name gets " 2", then " 3". The menu has a "Saved reports" list with Reveal and Delete. Delete is your own click, asks once and moves the file to the Trash | PA |
| 19 | **Agents: a web address you type in the task.** Should he open an address you type yourself? First proposal: no. The setting that blocks addresses from the screen also blocks typed ones, and he finds the page by searching. Saying yes leaves Phew's own removal of addresses as the only guard for the screen text: more risk, for a more natural "read this page" task | PA |
| 20 | **Agents: what may go into search words.** Should search words be limited to the words of your task? Safer for names of clients and people. Research about what is on your screen gets weaker. First proposal: no limit. Search words may include names from your screen or the Map, and the consent screen says so | PA |
| 21 | **Agents: a public test page for the hidden-instructions check (PA.5).** The live check needs a real web page with hidden instructions. Reading pages runs at Anthropic, so the page must be on the internet; a page on this Mac cannot be reached. It holds only made-up text and never the project's name or yours. First proposal: wait. The live check on a public page is run after phase PG, so that nothing goes on the internet before you choose to publish there. Until then the unit tests and the 10 live runs with a made-up screen cover the case. The other choice: one made-up page on a free public page service now | PA |
| 22 | **Conductor: task or question when unsure.** When Phew is unsure whether you gave a task or asked a question, he answers as a question. First proposal: yes. An answer is quick; a task runs in the background and costs more | PA |
| 23 | **Research reports do not write facts to the Map.** After a research task only one line is stored: your task and its Project. The report is not sent to the Librarian in version 1, so nothing read on the web becomes a fact in the Map. First proposal: yes for version 1. Learning facts from a report is listed under Later | PA |
| 24 | **Speech: which languages.** Which languages must speech input understand in the MVP: Italian, English or both? First proposal: both | P6 |
| 25 | **Numbers in the Map are first proposals** (`05-map.md`). Defined terms: 14, 7 and 90 days, 0.5. Starting confidence: 0.9, 0.6, 0.5, plus 0.1 when seen again. Strength values: 0.3, 0.1, 0.9, 0. 3 turns kept for 5 minutes. A profile of at most about 200 lines. At most 2 Map searches per question, 10 results per search, 3 lines per list, 30 search words. 20,000 characters per import call. First proposal: keep them all as written and tune after the MVP test | PM |
| 26 | Which business target to explore first, if any | After the MVP |
| 27 | Order of the later phases | Retro |

## 7.3 Parking list

- **Research: what similar tools use for agents.** Which models and agent frameworks Clicky and comparable tools run on, and how they keep calls cheap and fast: model routing, caching, small models, on-device steps. Do this before the backend phase. Partly answered in phase PR: see `10-research.md` 10.2 and 10.4. Still to find out: which models and agent frameworks the other tools run on.
- **Your own AI subscription.** Claude Pro and Max cannot be used: Anthropic forbids subscription sign-in in third-party apps, so Claude needs an API key. ChatGPT Plus and Pro may be possible through "Sign in with ChatGPT" (autumn 2026, partner apps); check OpenAI's own documentation on who can join. Would remove Phew's model cost per user. Needs a second provider behind the provider interface. After the MVP, as L9.
- **Tool connections (MCP).** Phew reads a project through the tool's own connection, for Figma, Notion and others, not only through the screen. After the MVP, as L9. From the Claude API only public servers can be reached, so a local connection needs its own client.
- **Independent work.** Research and new files are in the MVP (phase PA). Editing existing files and acting in apps stay later (L5).
- **Follow-up questions.** In the MVP, P5.5.
- **Following a guide is slow and costs more than estimated.** Measured on 29 real looks: 1 s wait, then 2.1 s on average and up to 6.2 s; 0.9 cents per look. Scrolling also triggers looks. In the MVP as phase PS. Left for later: the small model as a first pass with a narrower question.
- **The project has no copy off this Mac until phase PG.** Your decision of 13 November: no backup before then.
- **`TextCard.swift` does three jobs** (card, guide, following). Split in PS.7.
- **The card can cover a guide's target.** Move it out of the way if it bothers you.
- **Prices seen in the research were read through a summarising tool.** Check the live page before quoting one.
- **Before building any reader of export files**, request one export from each assistant and look inside: no format is documented.
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
| 13 Nov 2026 | P4 | P4.7 built and hand-tested: the guide follows you, no buttons. Works, feels slow. P4 complete. Full review done; $0.52 spent on the model so far. Phase PG GitHub and project structure added at the end of the MVP. GitHub guide written | PR Research and review |
| 14 Nov 2026 | PR | Research and review, no code. 13 Nov: product line and hard rules restated, research written in `10-research.md` with sources, market map drawn in Figma, deadline dropped, phases rewritten (P5, PB, PS, PA, P6, PT, PM, PG). 14 Nov: the Map redesigned for a general user with eleven classes, then all documents reviewed by seven reviewers, 70 problems confirmed and corrected. Nothing ticked: PR.1 to PR.6 wait for your approval. Three hard-rule changes approved and written. Phase PV, Your review, added | PV Your review, then P5 Map |

## 7.5 Your review of 12 November. Input to phase PR

In your words, shortened:

1. **Interactive steps.** If I do the step myself, for example change a sticky note's colour in Figma without clicking Next, the guide should continue by itself, reviewing what I do. Remove the Next and Continue buttons. Not intrusive, no extra things for the user to do. (Built as P4.7.)
2. **Connections.** MCP connections and project management across tools: connect Phew directly to a project or file in Figma or any other app.
3. **Independent work.** Today the tool is only useful for asking something specific. It needs logic for independent work that can edit locally: AI agents, editing things, deep project understanding.
4. **Usability and logic.** Usability is the main part, reached through UI and UX. The logic matters too: today it understands small specific things and does not feel like a tool to use when needed.
5. **Vision.** A way to use AI tools and models away from their own platforms, with a very interactive, easy interface.
6. **Deep understanding.** Improve the Map and the logic, and maybe other things not yet known.
7. **From student to general.** Not small tasks on projects, but understanding what the user is doing, why, and how to do what they ask. A professional tool, partly reached in the MVP.

Answered on 13 November 2026 in phase PR: product line and hard rules changed (7.1), research in `10-research.md`, phases rewritten in `06-sprint.md`.
