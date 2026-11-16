# Changelog

## 0.2.3, 16 November 2026

The rest of the developer review. Tested offline; nothing run live.

- Quicker jobs: the screen read from the shortcut serves the first step, no second look after writing a note, reminder, event or cells, and the picture is taken while the window is read.
- Memory that could not be opened is tried again, and the menu says "Memory is off" meanwhile.
- After you confirm an agent's change, the menu offers Undo until you open the result.
- A hold to talk ends without sending when the Mac sleeps or the screen locks. A key already held no longer blocks the shortcut.
- A project folder's files are read only while your memory holds that project.
- A word you corrected after a mishearing no longer counts as another name of the project.
- Links in a PDF report show their address only for web addresses.
- The app no longer freezes while a slow script runs; Stop can always be pressed.
- The Observer's code is removed. Debug files from an earlier test run are deleted at launch.

## 0.2.2, 16 November 2026

The serious findings of the developer review, fixed. Tested offline; the changed prompts and the real Notes, Reminders and Calendar scripts are not yet run live.

- A title or text can no longer be read as an option by the Mac's script runner (a note title starting with "-e" could have run a command).
- The whole-display picture and the screen watch leave out apps on the Never-read list, password managers and terminals.
- The secrets filter checks a field's name and value together, and catches secrets written with underscores.
- Undo checks before it says it failed, refuses when you changed the item after the job, and says what it could not bring back.
- A stopped call is logged at what it cost; a research task cannot ask for more than its money allows.
- Screen text is data, never instructions, for every agent.
- Links on the card open only web addresses and show where they go.
- The shortcut fires only with exactly its two keys; a hold ends by itself after 60 seconds.
- The disk image is built without the debugger door.

## 0.2.1, 16 November 2026

Phase N3, voice. Tested offline with the Mac's own voices; not yet with the model or a real voice.

- A misheard name is replaced by the known name it sounds like, on the Mac. Small gain: 5 of 12 test names right, 3 before.
- Spoken sentences are sent at once. He shows what he heard first only when he was unsure and is about to act, remember or start a task.
- A word you fix there is kept as "also heard as" on that name in your memory.
- "Remind me to call…" makes a reminder.

## 0.2.0, 16 November 2026

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
