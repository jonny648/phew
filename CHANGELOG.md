# Changelog

## 0.2.0, 17 November 2026

Phase N2, acting and agents second pass. Tested with stand-ins for the apps and for the model; not yet run live.

- He changes and deletes notes, reminders, events and cells, named by their exact title, with Undo on the card.
- A "can't be undone" tag on actions that send, publish, delete or replace. A research agent's change or delete waits in the menu for one confirm.
- He reads an app's menu commands before acting, and asks Chromium and Electron apps (Dia, Figma) to describe their controls.
- He returns you to the exact window; the pointer lands on a second display.
- Research plans first, reads what it cites, and ends every report with "Not checked". "Keep facts from …" proposes a report's facts for your memory, by tick.
- A task reserves its budget from the day's ceiling; the limits no longer read the call log on every request.

## 0.1.1, 16 November 2026

- Limits: a "Limits…" entry in the menu with requests per minute, requests per day and dollars per day. He stops and says so when one is reached.
- Lower cost: the text about himself is sent only when you ask about him; fixed instructions are cached for one hour when you use him often; a ceiling on the size of the whole-screen picture.

Not checked live: the one-hour cache, the routing of questions about himself, the scaled picture and the Limits panel were tested by the automatic tests only.

## 0.1.0, 16 November 2026

The MVP.

- Ask panel on Right Option + Right Command; answers in a card that is a conversation.
- Explains what is on screen; guides step by step by pointing and follows what you do.
- Acts in your apps from your words: presses, types, picks menus, clicks; several apps in one job; Notes, Reminders, Calendar and Excel through their own scripting. A list of things he never touches, Stop, and stopping on anything unexpected.
- The Map: an encrypted memory of your projects on the Mac, with a second lock for sensitive facts, forget and restore, export.
- Import of Claude's memory export (folder or zip), of a pasted memory list, and of a Claude Code project folder; undo last import.
- Tasks: he researches alone, up to three at once, saves a PDF report, and can add notes, reminders, events and sheets in the background.
- Voice: hold the shortcut and speak, on the device, Italian and English, with feedback at the notch.
- First run as one panel; a menu bar menu; no main window and no Dock icon.

Known to be weak: acting in Dia, Figma and Fusion is untried; names in spoken sentences are often misheard; changing, sending and deleting are not built. See L18 in `roadmap.html`.
