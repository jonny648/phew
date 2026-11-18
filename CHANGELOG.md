# Changelog

## 0.5.1, 18 November 2026

Phase NF, connections that work. Tested offline; nothing run with the model or a real connector.

- Naming a connected tool in your request now reaches it, in English or Italian. Before, tools were picked by shared words with their names, so Gmail, Calendar and Spotify got the wrong tool or none.
- He is told which tools you ticked, and uses one before the screen when you name it. A question about a named tool goes to a job, not to an explanation.
- Listing your Claude account's connectors takes about two seconds, not sixteen.
- A connector with no tools says "Sign in on Claude first" and cannot be ticked.
- Money tools (a broker or payment service, or a tool named for a trade, order, transfer, deposit, withdrawal) wait for your confirm in the menu bar, also in a job you watch.
- A connector step that fails says why on the card.

## 0.5.0, 18 November 2026

Phases NB (connections), N4 (cost down) and N7 (the brand), built as one. Tested offline; nothing run with the model, with a real connector or in real apps.

- Connections, in the menu: he reads and writes in the tools you connect. Notion through Phew's own sign-in. Off until you switch it on: "Use my Claude account", which reaches the connectors of your Claude account through the Claude Code program on your Mac, with your Claude plan paying.
- A read runs freely. A write is listed on the card; one asked by a background task waits for your confirm, and the row shows what will be sent.
- Your Shortcuts as tools: tick the ones he may run under "Shortcuts he may run".
- A deep research task may split into up to four workers; a finding whose page was not read is dropped, and one fresh read marks each claim.
- Cost: a job plans up to five actions in one call; a guide's click is confirmed without a call when the next control appears; he remembers once per conversation; smaller close-up pictures and shorter research pages.
- Quitting waits up to five seconds so a conversation's facts are not lost.
- A new look: the mark is the top of an eggshell in one heavy line, in the menu bar, on the card, at the notch while you hold the key, and as the app icon. Its pose, line and colour show what he is doing.

## 0.4.0, 17 November 2026

Phase NA, the limits review, decided and built. Tested offline; nothing run with the model or in real apps.

- More kinds of action: keys and shortcuts, scroll, drag, double click, right click. Any app, except the ones he never touches.
- Fewer false stops: a Save sheet no longer ends a job; at 20 actions a minute he pauses and goes on.
- "Add a line to my Groceries note" works. With several matches he lists them.
- Research: "Confirm all" for waiting changes, a deep size when you ask for it, a fourth task waits its turn.
- He reads files in folders you add under Memory, Folders he may read. A change to a file waits for your confirm; the old version goes to the Trash.
- Small text: a sharp close-up around the mouse. Long windows: up to 20,000 characters, read in pieces.
- A follow-up can ask about the previous screen for 10 minutes. Conversations are kept under Memory, Conversations.
- Off until you switch them on: "Let Phew watch one thing" and "Notify me".
- A shortcut you can set; request ceilings in Limits.
- Password managers and Keychain Access are never read. "Send as it is" when a key was left out of your question.

## 0.3.1, 16 November 2026

Skills in a job you watch, and the last leftovers of the review. Tested offline; not yet with the model.

- In a job you watch he can write a skill, run it and use the result in the next step. The card lists each skill step. Stop ends a running skill.
- A project folder is remembered only while its project is in your memory.
- Memory waits a moment when it is busy instead of failing; fewer reads for each answer and each keep.

## 0.3.0, 16 November 2026

Phase NC, first form: skills. Tested offline with the real helper in the real box; not yet with the model.

- During a research task he can write a small function for himself, test it, keep it and use it again. A skill only computes: text in, text out.
- Skills run in a closed box: a small TypeScript helper on Node inside the app, with no network, no file writes, no apps.
- Memory, Skills… in the menu lists them, with Delete. A report names the skills its task used.
- The app is now about 125 MB (Node is inside it). Apple silicon only.

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
