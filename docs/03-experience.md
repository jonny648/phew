# 3. Experience

## 3.1 Three surfaces, one character

| Surface | Role | Behaviour |
|---|---|---|
| Notch | Home | Phew rests here in his shell. Expands slightly to show state and working agents |
| Menu bar | Fallback home and controls | Used on Macs without a notch. Holds settings, the "Never read this app" list, link to dashboard |
| On-display presence | Explaining and guiding | Phew leaves the notch, travels to the spot, becomes a second cursor to point or show, then returns |

The on-display presence is the heart of the product. Phew turns into a pointer with a soft effect, indicates an element, underlines, circles or walks through steps, and places a short text card beside it when words are needed. He never speaks aloud.

Difference from Clicky: silent instead of voiced, lives in the notch instead of following the cursor all the time, and the pointer is a temporary form, not his permanent one.

## 3.2 States

| State | Where | Look |
|---|---|---|
| Resting | Notch | Inside the shell |
| Listening | Notch | Peeks out, shell tilts |
| Thinking | Notch | Small steady motion |
| Guiding | On display | Pointer form, trail, highlight |
| Working | Notch | One small egg per running agent. An egg hatches when its task is done |
| Waiting for you | Notch | A quiet mark. He does not come out |

## 3.3 Ways to call him

All are effortless and none needs a choice.

| Way | How | MVP |
|---|---|---|
| Hold a key and speak | Hold one key, say what you need, release | Yes |
| Shortcut | One global shortcut, then type a few words or nothing | Yes |
| Click | Click him in the notch or menu bar | Yes |
| His name | Say phew, few, phiu, pheoo. Matched loosely on device | Later |

With nothing said, he explains what is under the cursor. He works on the whole window, a region, a selection or the full screen. Selection is one input among several, not the logic of the product.

## 3.4 What he does

- **Work with you and act.** Asked to do something, he does the whole job by himself in your apps, in several apps if the job needs it. Asked how, he shows. Rules in 3.6, design in `13-hand.md`. In the MVP (phase PH).
- **Explain.** What is this, in the context of your project.
- **Guide.** Shows the next step on screen, one step at a time, in any app.
- **Remember.** Learns each time you work on a project. Nothing to save by hand.
- **Research alone.** You give a task, such as a short research or collecting sources. He works in the background and the result waits in the menu bar. He may also act in the background, in the narrow way described in 3.6. In the MVP.
- **Listen to lectures.** Captures a lesson and keeps the important details you may miss while writing notes, linked to its project. Later.
- **Work in the background.** Scheduled work, and silent housekeeping on his own. Later.

## 3.5 Agents in the UI

Agents are visible as a pleasant detail, never as a control panel. Eggs in the notch show how many are working. Hovering shows one line per agent. Full history lives in the dashboard.

In the MVP: a "working" mark on the menu bar icon with the number of tasks running, a Stop entry per task in the menu, and the result waiting in the menu until you open it on the card. He never shows a result by himself. An agent's action that cannot be undone, or that leaves your Mac, also waits in the menu for one confirm from you. Before the first task, one screen says in plain words what a task may read and send.

The screen's text. You approved it on 14 November. Lines were then brought in line with your other answers of the same day: reports are always saved, an address you type is opened, the project's Claude Code files are read when needed, and several tasks can run:

> **Phew can research a task by himself.**
>
> He reads your screen once, when you give the task. He looks in his memory of your projects, and in the project's Claude Code files when the task needs them. He searches and reads the web, and opens a web address you type in the task.
>
> What leaves your Mac: your task, what he saw on your screen, the facts from his memory and the parts of the project's Claude Code files that the task needs are sent to Claude, the model made by Anthropic. The web search and the reading of pages run at Anthropic too. The words he searches for can include names from your screen or his memory. Passwords, keys and card numbers are removed before anything is sent.
>
> What he changes on your Mac: nothing, except new files. He saves each report as a new PDF in the folder you chose, or in Downloads, and keeps a copy for himself. He never overwrites or deletes a file.
>
> Each task has a limit on searches, pages and cost. A mark in the menu bar shows he is working. Each task has its own Stop. The result waits in the menu bar until you open it.
>
> [Allow] [Not now]

After Allow the screen is not shown again. After Not now the task does not start, agents stay off, and the screen comes back the next time you give a task.

One line of this text is older than your decisions of 15 November: "What he changes on your Mac: nothing, except new files." An agent may now also act in the background, in the narrow way described in 3.6. The text above is the one you approved, so it is left as it is; a new wording of that line is yours to approve before agents act (phase PA). Acting has its own short consent screen, in 3.6.

## 3.6 What he may do alone: consent levels

Decided on 13 November 2026 after the research in `10-research-agents.md` 10.2. Level C changed on 15 November 2026: acting moved into the MVP, design in `13-hand.md`.

| Level | What he may do | When |
|---|---|---|
| A. Read and research | Read the screen once when you give the task, read the Map and the project's Claude Code files when needed, search and read the web, open an address you type, report on the card | MVP |
| B1. New files | Save the report as a new PDF in the folder you chose, or in Downloads, and a Markdown copy in Phew's own storage. He never overwrites and never deletes. Each report is listed with Reveal and Delete. Delete is your own click | MVP |
| B2. Edit files | Change existing files in that folder, each change shown and approved, with a backup | Later |
| C. Act in apps | When you ask him to do something, he clicks, types and picks menus in your apps: the whole job, with no confirm. A research agent acts only in the background, in the narrow way below. Off until you press Allow on the acting consent screen | MVP, phase PH. For agents, phase PA |

Rules for a research task, each with how it is kept: by Phew's own code or by the request, not by asking the model to behave. The rules for acting are under "Acting in your apps" below.

- What he reads from the screen, the Map, the web, a file or pasted text is data, never instructions. A web page cannot give him orders. No defence here is perfect: a page can still try to steer what he searches for next. The rules below keep the damage small.
- He searches, reads and reports. Phew's own code saves the finished report, never the model, as new files only: the PDF in the folder you chose or in Downloads, the Markdown copy in Phew's storage. He never overwrites or deletes a file.
- When a task needs an action (phase PA), he acts only through ways that do not take your screen: the apps' own scripting and the system's calendar and reminders access, in Notes, Reminders, Calendar and Excel, plus new files. He never clicks in the background and brings no app to the front. He may read back what he just wrote, to check it. Anything that cannot be undone, or that leaves your Mac, is not done: it waits in the menu bar for one confirm from you.
- He never opens a web address that came from the screen, the Map or a file. Two guards. Phew's own code removes every web address from the screen text, the Map facts (also the ones a Map search returns) and file text before they reach him. And a setting of the web fetch tool lets him open only addresses he found by his own searches, on pages he already opened, or typed by you in the task. Anthropic's server refuses any other. An address you type is opened: your decision of 14 November. It leaves Phew's own removal as the only guard for the screen text, which is the risk you accepted.
- Each task has a limit on searches, pages and cost: 5 searches, 8 pages, 50 cents, approved 14 November. Rate limits on usage come after the MVP. The limits on searches and pages are set in the request itself, so they hold while the work runs at Anthropic. Phew's own code adds up the cost after each reply. At a limit he stops, reports what he has, and says which limit he reached.
- He reads the screen once, when you give the task, and not again. What he read stays in memory until the task ends or is stopped. Then it is dropped.
- The secrets filter runs on everything Phew sends. He writes his search words at Anthropic, from text that already passed the filter. They may contain names or words from your screen or the Map, with no limit: your decision of 14 November. The consent screen says so.
- A mark shows while he works, and Stop always works. Stop ends the task within 2 seconds. Nothing is reported and what he read is dropped. Approved 14 November.
- Several tasks can run at the same time, at most 3 (first proposal). Each has its own limits, its own Stop, and its own screen read. A fourth task is not started, and the card says so in one line.
- A finished report is saved at once, as below, and waits in the menu until you open it. Nothing is lost if Phew quits.

How a report is saved. Approved 14 November:

- You choose the folder once, from the menu entry "Choose reports folder…", in the system folder window. That window is the one written exception to the focus rule. You can change the folder there.
- Each report is saved by itself as soon as the task ends. With no folder chosen, it goes to Downloads.
- You get a PDF, because it is easy to read. A Markdown copy goes to Phew's own storage, `~/Library/Application Support/Phew/reports/`, for Phew and the agents only.
- The name is the date and the first words of your task, for example `2026-11-20 Kerning sources.pdf`. The name never comes from the model or from a web page. Phew's code cleans it: no slash, no "..", no dot at the start.
- If that name exists, the new file gets ` 2`, then ` 3`. The file is created only if no file with that name exists, so no existing file is ever replaced.
- Phew checks that the file lands inside the folder. It does not follow a shortcut in the folder that points elsewhere.
- The file holds the report only. The screen text and the picture he read are never written to it.
- The menu has a "Saved reports" list. Each has Reveal, which shows the PDF in Finder, and Delete. Delete is your own click, never the agent's. It asks once and moves the PDF and its copy to the Trash.

### Acting in your apps

Your decisions of 15 November 2026. The full design, the guards and what can still go wrong are in `13-hand.md`. Phase PH; not built yet.

There are no "Do it" buttons and no confirm. Whether he acts or shows comes from your words and from what you do.

| You say or do | He |
|---|---|
| "Make the title bold." "Add a reminder for Friday." | Does the whole job by himself |
| "How do I make it bold?" "Where is the export?" | Shows you, by pointing |
| Words that could mean either | Shows |
| You start doing a step yourself | Stops acting. The job is yours again |

| Level | Examples | Rule |
|---|---|---|
| Show | Point, highlight, scroll to | Always allowed |
| Acts | Click, type, pick a menu, fill cells. Also send, delete, publish and replace, when that is the job | Done when your words ask for it. No confirm |
| Never | Passwords and secure fields, paying and card details, sign-in and account settings, System Settings, Terminal and code editors, password managers, apps on the "Never read this app" list, Phew's own windows | Not done, whatever the words. Phew's own code decides, never the model |

- **Off until Allow.** Before his first action a short consent screen is shown once (text in `13-hand.md` 13.8). One consent covers all apps. After Not now he keeps pointing only.
- **Every action is listed on the card** as it happens, and a mark shows while he acts. An action that cannot be undone carries a mark in the list.
- **He checks after each action** by looking again. When something is not as expected he stops by himself and says so. He never retries blindly.
- **Stop ends a job within one second.** Stop is on the card the whole time. The shortcut stops too, and so does using the app yourself.
- **Several apps in one job.** He brings the other app to the front, works there, and returns you to where you were.
- **A research agent** acts only in the background, as written in the rules above.

## 3.7 Web dashboard

On his website, after sign in:

- The Map: your projects, tasks, topics, people and how they connect. Editable.
- Lectures and notes.
- What agents did.
- Privacy: what is kept, delete anything, apps never read, export.
- Account and plan.

## 3.8 Order and brand

One motion language, one palette built on black and shell white, one type family, the same timing curves everywhere. The brand sheet is written in the character phase, after the MVP.

## 3.9 MVP and later

| In the MVP | Later |
|---|---|
| Home in the menu bar | Home in the notch, character, animations |
| Shortcut, click, hold key and speak | His name as wake word |
| Acts in your apps when you ask: the whole job, in several apps if needed. Agents act in the background in a narrow way (3.6) | Editing existing files on disk directly |
| Explain and guide with a simple pointer and text card. The card opens into a conversation (3.10) | Pointer effects, eggs for agents |
| Remembers your projects, on the Mac. Recall at any time | Dashboard and Map view online |
| Learns from your other AI tools: a pasted memory list, Claude Code files | Reading export files, connections to other tools |
| Researches a task alone, reports on the card, saves the report as a file | Scheduled work, lecture listening |

The MVP must solve the main problem: understand and move forward on what is in front of you, with no re-explaining. The look and feel is its own phase inside the MVP (PX). The notch home and the character come after.

Lecture listening, when built, shows a recording notice in the way Granola does. For personal use now this is not a concern.

## 3.10 The conversation card

Design for task PS.10, written and approved by you on 15 November 2026. Built in PS.11. It answers P5.16: today a follow-up is one message, with no way to continue in the card. Background: what other tools do, in `11-direction.md` 11.10.

Your idea: the answer card opens, on a click, into a chat-style card.

### What you see

1. **Closed, as today.** The answer card, 360 points wide, beside the spot. One new line at its bottom, in grey: "Reply…". It shows the card can be continued.
2. **Opening.** A click anywhere on the card opens it. The same card grows downward. No second window appears and the answer does not jump anywhere. (Tab was in the first design. Built in PS.11 without it: while the card is closed your keys go to your app, so a Tab there belongs to your app and must not open the card.)
3. **Open.** About 400 points wide and up to 520 tall.
   - Your questions and his answers, oldest at the top, newest at the bottom. Older ones scroll inside the card.
   - A reply field at the bottom, with the cursor already in it.
   - Return sends. Shift and Return makes a new line.
   - A close control at the top right.
4. **While he answers.** The words appear as they arrive, as today. You can type the next reply meanwhile; it is sent when the answer is done.
5. **A guide inside a conversation.** When a reply asks to be shown ("show me"), the pointer runs as today. Each step is added to the thread as one short line. The card moves aside if it covers the spot the pointer marks.
6. **Place and size.** It opens where the answer card already was, and is kept inside the screen. You can drag it. It never opens at a random spot.

### Closing

- Escape, the close control, or the shortcut pressed when the reply field is empty. A guide ending does not close an open conversation.
- After 10 minutes with no reply the conversation ends and the card closes. Your choice of 15 November.
- Pressing the shortcut while a conversation is open puts the cursor back in the reply field. It does not open a second card.
- After closing, the next call starts a fresh card.

### Typing without taking focus

- Phew is never made the active app. The card takes typing the way the input panel already does (`KeyWindow.swift`): it receives keys while the front app stays the active app.
- When the card closes, the front app has the keyboard back, with no click needed. This is checked by hand in PS.11, because other tools shipped this bug.

### The screen

- The first question reads the screen once, as today.
- A reply does not reuse that capture. The rule stays: a capture is never kept for a follow-up.
- Every reply takes a fresh look at the screen, then drops it when the answer is done. Your choice of 15 November: always, with no switch. Each reply is a little slower and costs more than a reply with no look; measured in PS.11.
- A guide inside the conversation looks and watches as any guide does, and drops what it saw when the guide ends.

### Memory

- The conversation lives in memory only. Nothing of it is written to disk or to a log.
- Each reply sends the earlier questions and answers as text, plus a fresh recall from the Map. The secrets filter runs on the whole text again before every call, because it leaves the Mac again each time.
- The limit of 3 turns and 5 minutes (P5.5) is replaced: the conversation keeps its last 8 turns for as long as it is open, at most 10 minutes without a reply. Older turns are dropped, not summarised. First proposal.
- What lasts after closing is what the Map already keeps: the question as a past question, and the facts the Librarian learned. The Librarian reads each turn as it does today.
- Each turn is one line in `calls.log`, with numbers only.

### Cost

Each reply resends the earlier turns, so a long conversation costs more per reply. The fixed part of the request and the earlier turns are cached, which makes repeated text cost about a tenth. Measured in PS.11.

### Rules this changes, named

- `02-vision.md` 2.7 "Not a chat app" and 2.2 "with no chat". Reworded in PD.3: Phew is not a chat app you keep open; a conversation starts from what is on your screen and ends when you close it.
- The P5.5 follow-up limits (3 turns, 5 minutes), replaced as above.
- "No main window": kept. The conversation is the same small card, non-activating.
- No privacy rule changes. Keeping whole conversations, or a list to resume them, stays an open decision (`07-decisions.md` 7.2, number 34) and is not built.

### Not in this design

- No list of past conversations, no search in them, no resume.
- No attachments, no voice inside the card (voice is phase P6).
- No settings panel for the limits.
