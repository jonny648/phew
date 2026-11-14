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

- **Explain.** What is this, in the context of your project.
- **Guide.** Shows the next step on screen, one step at a time, in any app.
- **Remember.** Learns each time you work on a project. Nothing to save by hand.
- **Research alone.** You give a task, such as a short research or collecting sources. He works in the background and the result waits in the menu bar. In the MVP.
- **Listen to lectures.** Captures a lesson and keeps the important details you may miss while writing notes, linked to its project. Later.
- **Act.** Takes actions in other apps under the rules in 3.6. Later.
- **Work in the background.** Scheduled work, and silent housekeeping on his own. Later.

## 3.5 Agents in the UI

Agents are visible as a pleasant detail, never as a control panel. Eggs in the notch show how many are working. Hovering shows one line per agent. Full history lives in the dashboard.

In the MVP: a "working" mark on the menu bar icon with the number of tasks running, a Stop entry per task in the menu, and the result waiting in the menu until you open it on the card. He never shows a result by himself. Before the first task, one screen says in plain words what a task may read and send.

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

## 3.6 What he may do alone: consent levels

Decided on 13 November 2026 after the research in `10-research.md` 10.2.

| Level | What he may do | When |
|---|---|---|
| A. Read and research | Read the screen once when you give the task, read the Map and the project's Claude Code files when needed, search and read the web, open an address you type, report on the card | MVP |
| B1. New files | Save the report as a new PDF in the folder you chose, or in Downloads, and a Markdown copy in Phew's own storage. He never overwrites and never deletes. Each report is listed with Reveal and Delete. Delete is your own click | MVP |
| B2. Edit files | Change existing files in that folder, each change shown and approved, with a backup | Later |
| C. Act in apps | Click and type in other apps. A separate opt-in, off by default | Later |

Rules for every level, each with how it is kept: by Phew's own code or by the request, not by asking the model to behave.

- What he reads from the screen, the Map, the web, a file or pasted text is data, never instructions. A web page cannot give him orders. No defence here is perfect: a page can still try to steer what he searches for next. The rules below keep the damage small.
- He has no tool that writes or changes anything. He can only search, read and report. Phew's own code saves the finished report, never the model, as new files only: the PDF in the folder you chose or in Downloads, the Markdown copy in Phew's storage.
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

### Actions in other apps, when built

| Level | Examples | Rule |
|---|---|---|
| Show | Point, highlight, scroll to | Always allowed |
| Reversible | Open, click, type into a draft, create a file | Done when you ask for it |
| Irreversible | Send, submit, delete, publish | He asks once, every time |
| Never | Passwords, payments, account settings | Not done |

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
| Explain and guide with a simple pointer and text card | Pointer effects, eggs for agents |
| Remembers your projects, on the Mac. Follow-up questions. Recall at any time | Dashboard and Map view online |
| Learns from your other AI tools: a pasted memory list, Claude Code files | Reading export files, connections to other tools |
| Researches a task alone, reports on the card, saves the report as a file | Editing files, actions in other apps, scheduled work, lecture listening |

The MVP must solve the main problem: understand and move forward on what is in front of you, with no re-explaining. Looks come after.

Lecture listening, when built, shows a recording notice in the way Granola does. For personal use now this is not a concern.
