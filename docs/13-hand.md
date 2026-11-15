# 13. The Hand: Phew acts in the front app

Written on 15 November 2026 for decision 39 in `07-decisions.md` 7.2. Updated on 15 November 2026 to your decisions of that day. Approved with the plan of that day. Built so far: the acting core of 13.6 (PH.2, 15 November). The rest is being built in phase PH.

How to read it. Each fact from the web carries a source number (H1, H2…), listed in 13.11. Three words mark how sure a claim is:

- **Verified**: read today on the vendor's own page, or checked today on this Mac by reading the app's own files.
- **Inferred**: follows from how that kind of app normally behaves. Likely, not checked.
- **Not verified**: could not be checked without building and running. Every such claim is marked.

Nothing was run against a live app for this document. No click, no key, no script was sent to any app. So every claim about how well an action *works* in an app is "not verified" until phase PH measures it.

## 13.1 What changes and why

Today Phew explains and points, and you do every step yourself. On 15 November you decided that he should also act, and how. When your words ask for doing, he does the whole job by himself. There is no button to press and no question before a step. He may work in several apps in one job. The research agents may act too, in the background, in a narrow way. What stays: a visible mark, a list of every action, a Stop that always works, a check after every action, and a list of things he never does. This design bends four rules in `CLAUDE.md` and adds to two more. All six are named here so nothing changes quietly. They are written into `CLAUDE.md` in task PD.3.

| Rule in `CLAUDE.md` today | What changes |
|---|---|
| "An agent… changes nothing, except new files… It never overwrites or deletes" | Bent. When you ask, Phew changes things in your apps. The research agents also act, in the background, only through the apps' own scripting and the system's calendar and reminders access: Notes, Reminders, Calendar, Excel, new files. For an agent, anything that cannot be undone or that leaves the Mac waits in the menu bar for one confirm from you |
| "Nothing from the 'Later' section of the roadmap is built during the MVP" | Bent. L5 Hand moves into the MVP as phase PH. Only the half "actions in other apps". The other half of L5, editing existing files on disk directly (level B2), stays Later |
| "He reads the screen only when called. During a guide he may watch the screen… and look again after the user acts" | Bent. He also looks again after *his own* action, to check that it worked. In a job across apps, that includes the app he brought to the front. Same look, same limits, same memory-only rule. Today's code has a hard rule that a look happens only after you act (`FollowRule.swift`); that line changes too |
| "He never activates the app or takes focus from the front app" | Bent. Working across apps brings another app to the front during a job you asked for. He returns you to where you were. Phew's own panels stay non-activating, and Phew itself still never becomes the active app |
| Logging rule ("A line in `calls.log` holds only…") | Added to, not loosened: a new local action log, numbers and fixed words only. See 13.6, guard 11. This is a privacy rule, so it is named |
| "Never read secure text fields" | Added to: never *write* into one either, and never act while the Mac is in secure input mode. This is a privacy rule, so it is named |

Rules that stay exactly as they are: he never appears unasked, he never speaks, captures live in memory only, the secrets filter runs before every network call, on-screen text is data and never instructions. Your decision of 12 November also stays: acting is a separate opt-in, off by default. The consent screen (13.8) is that opt-in.

One earlier finding, for the record. `10-research-agents.md` 10.2 said that acting "breaks the rule that Phew never takes focus". Inside one app it does not: the action goes to the app that already has focus. Across apps it does, and that is the fourth bent rule above.

## 13.2 How Phew can act: the methods

There are six ways a Mac app can act in another app. Phew is not sandboxed and already has the Accessibility permission, so the first two need no new permission from macOS.

| Method | What it is | Permission | Works in | Fails in | Can it be checked after |
|---|---|---|---|---|---|
| 1. Accessibility actions | Phew asks the app to do something to one named element: press it (AXPress), set its value (AXSetValue), open its menu (AXShowMenu), pick a menu item, step a value up or down (AXIncrement, AXDecrement) | Accessibility. Already granted (H2) | Native Mac apps, the menu bar of almost every app, web pages in Chromium browsers once the full tree is asked for (Phew already does this to read). Inferred | Canvas and custom-drawn areas (the Figma canvas, a 3D view), controls that list no action, some web buttons that react only to a real mouse. Other tools keep a chain of fallbacks for this reason (H2), so a press alone is not always enough | Yes, well. The same element can be read again: its value, whether it is ticked, whether it still exists. Then the existing look confirms |
| 2. Synthesized events | Phew makes a mouse click or key press as if you had made it (CGEvent) | The same Accessibility switch covers posting events. No extra entitlement (H3). Verified from Apple's forum, not from a test | Everywhere a real click works, including canvases | It clicks a *place*, not a *thing*: if the screen moved, it hits something else. Keys go to whatever has focus at that instant. Behaviour while a password field is focused (secure input) is not verified (H4). The mouse pointer visibly jumps | Only by looking at the screen again |
| 3. Apple Events (AppleScript) | Phew sends a command in the app's own scripting language: "make a new reminder", "set the value of cell B2" | A new macOS prompt, once per app: "Phew wants to control Excel". Phew would also need one new signing entitlement and one text in its Info file (H5) | Only apps with a scripting dictionary. On this Mac: Excel, Notes, Reminders, Calendar, Dia. Verified | Figma and Fusion have no dictionary. Verified. A script changes the app's data, not what you see, so it can act on things that are not on screen | Yes, very well: read the same property back |
| 4. EventKit | Apple's own way for an app to add reminders and calendar events | A new macOS prompt each for Reminders and Calendar (H6) | Reminders and Calendar only | Everything else. It works behind the app, not in it | Yes: read the item back |
| 5. Shortcuts | Phew runs a shortcut you already made, by its name (H7) | None to start one. The shortcut may ask for its own | Whatever your shortcuts do | Phew cannot use another app's built-in actions directly, only shortcuts you built. Not verified | Poorly. Phew only learns whether it ended |
| 6. Model-driven "computer use" | Claude's own tool. The model looks at a screenshot and replies with actions (click at x, y; type; key; scroll; drag). Phew's code would have to carry them out with method 2 and send a new screenshot back, in a loop (H1) | Same as method 2 | Anywhere, in principle | Slow: one model call and one picture of about 1,000 to 1,800 tokens per step. Anthropic's page lists misses on small targets, trouble with dropdowns and scrollbars, and says the model "sometimes assumes an action succeeded without checking" (H1) | Only by another screenshot |

What the Claude API offers today (H1, read 15 November 2026): the current tool is `computer_toolset_20260801`, with no beta header, for the current models including the Sonnet and Haiku classes Phew uses. The older `computer_20251124` needs the header `computer-use-2025-11-24` and is for older models only. The tool returns `tool_use` blocks, often several at once, with actions such as `screenshot`, `zoom`, `left_click`, `left_click_drag`, `scroll`, `type`, `key`, `wait`. Anthropic runs none of them. The app runs each one and sends back a result, with a picture for `screenshot` and `zoom`. Read the page again before building; names change.

### Recommendation

**First: method 1, Accessibility actions on elements Phew already lists.** Today the reader gives every control an id (e1, e2…), a role and a name, and the Guide already ties each step to one of them. Acting on that same element is the smallest step from pointing to doing. It needs no new permission, it does not move your mouse, it names the thing it acts on so Phew's code can judge the risk by name, and it can be checked by reading the element again. Menu bar items belong here too, and they matter: in apps that expose little (Figma, Fusion), most commands still sit in the menus, by name.

**Fallback: method 2, but only a single click.** Used only when the target has no Accessibility action, which is the normal case on a canvas. One click, at the centre of the spot the pointer marks, after checking that nothing has moved. No drag. No free typing through key events in the first build: text goes in through method 1 (set the value of a field, or insert at the cursor of a text area).

One job may use different methods for different steps: a menu item here, a script there. For a single step, the method is chosen *before* acting, by reading which actions the element lists. If the step seems to fail, he looks first. He does not fire a second method blind: if the first had worked slowly, the second would do the step twice.

**Later in the phase, per app: method 3 for Excel, and method 3 or 4 for Notes, Reminders and Calendar** (task PH.10). For "put these numbers in these cells" or "add this reminder", a script is more exact than clicking and can be read back. It costs one new entitlement, and macOS shows its own prompt once per scripted app ("Phew wants to control Excel"). That prompt is macOS's, not Phew's, and Phew cannot remove it. Phew himself asks nothing per app. These are also the only methods a research agent may use in the background (13.4), because they do not take your screen.

**Not at all in the MVP:**

- Method 6 as the driver. In that loop the model picks each next action by itself from whatever is on screen. It acts on places, not on named things, so Phew's code could not judge an action by its name against the Never list. It is the slowest method, and it is the one every documented attack in 13.7 goes through. Phew already has a Guide that plans the steps of a job and a Follower that checks them; the Hand carries each step out. No new agent is needed.
- Running JavaScript inside a browser page. Dia's dictionary offers it (verified on this Mac). It gives full power over the page you are logged in to. Never.
- Method 5, Shortcuts. It cannot be checked and nothing in the seven apps needs it.
- Raw keyboard shortcuts (Command-Q, Command-Delete and the rest). A key combination has no name the code can judge. He picks the menu item instead, which has one.
- Drags.

## 13.3 The seven apps

"Checked on this Mac" means the app's own files were read today (its scripting dictionary and its declared web-address schemes). It does not mean an action was tried.

| App | What he could do, and how | How sure |
|---|---|---|
| **Figma** (desktop) | Menu items by name, through method 1. Clicks on the canvas and on panels through method 2, at a point taken from the screenshot. No scripting: no dictionary. A `figma://` address scheme exists. The app is built on Electron. Figma keeps a hidden text copy of the canvas for screen readers, behind a setting (H8) | No dictionary, Electron, the scheme: verified on this Mac. Menu items: inferred. Whether toolbar and panel buttons can be pressed by name, and whether the screen-reader copy helps Phew: not verified. Your own note of 12 November says Figma exposes no text, so expect mostly method 2 |
| **Dia** (browser) | The browser's own controls (tabs, back, the menus) through method 1 or its dictionary: windows, tabs, focus, open, close. Links, buttons and fields on a page through method 1. Whether he may act on pages at all is your decision (13.9) | Dictionary and its commands: verified on this Mac. Page elements pressable by name: inferred from how Chromium browsers behave, not verified in Dia |
| **Excel** for Mac | Menu items through method 1. Cell values and formulas through method 3: the dictionary is large (207 kinds of object, with workbook, worksheet, range and cell). Address schemes `ms-excel:` exist | Dictionary and schemes: verified on this Mac. Ribbon buttons and single cells by name through method 1: not verified. Whether a change made by script can be undone with Command-Z: not verified |
| **Autodesk Fusion** | Menu items through method 1, clicks in the 3D view and toolbars through method 2. No scripting dictionary. Fusion has its own Python programming interface, but it runs only inside Fusion as an add-in you install (H9); not for the MVP | No dictionary in the app's launcher: verified on this Mac. Everything about what Fusion's toolbars and panels expose: unknown. The least sure of the seven |
| **Notes** | Buttons, the note list and the text area through method 1. Creating a note or a folder through method 3. A `notes:` address scheme exists | Dictionary (accounts, folders, notes, attachments) and scheme: verified on this Mac. Method 1: inferred; Notes is one of your reading test apps and reads well |
| **Reminders** | Tick a reminder, press buttons through method 1. Create a reminder with name, notes, due date, priority, flag through method 3, or method 4 | Dictionary with those properties: verified on this Mac. EventKit access: verified from Apple's pages (H6). Method 1: inferred |
| **Calendar** | Switch view and press buttons through method 1. Create an event through method 3 or method 4 | Dictionary (calendars, events, attendees, alarms; "make", "switch view", "show"): verified on this Mac. EventKit, including an add-only level of access: verified from Apple's pages (H6). Method 1: inferred |

What this table says plainly: for the three Apple apps and Excel there is a solid, checkable way. For Dia it is likely. For Figma and Fusion, the two apps where the most work happens on a canvas, acting will mostly be single clicks at a point, plus menu items. That is the weakest method. Task PH.8 measures all seven apps, and task PH.9 measures how often a click on a canvas lands right.

## 13.4 The shape of collaboration

There are no "Do it" and "I'll do it" buttons. Whether he acts or shows comes from your words and from what you do.

| You say or do | He |
|---|---|
| "Make the title bold." "Add a reminder for Friday." | Does it |
| "How do I make it bold?" "Where is the export?" | Shows you, as today |
| Words that could mean either | Shows |
| You start doing a step yourself | Stops acting. The job is yours again, and he follows you as a guide |

The Conductor, the small model that already sorts your requests, decides between "do" and "show" from your words.

What you see, step by step.

1. **You call him and ask**, as today.
2. **He does the whole job.** No approval per step. No limit of one action per approval. He does not pause before send, delete, publish or replace.
3. **A mark shows while he acts.** The menu bar icon changes, and a ring sits on the spot he is acting on.
4. **Each action is listed on the card** as it happens, in plain words: "Pressed Bold." "Typed 12 characters in Title." Then a tick when the check passed. An action that cannot be undone carries a mark in the list. The list stays on the card until you close it. It lives in memory only.
5. **After each action he looks.** First Phew's own code reads the element again: did the value change, is the box ticked, did the menu close. Then the existing look (the Follower, with a fresh picture) confirms where the job stands. Only then does the next step start.
6. **Stop always works.** Stop is on the card the whole time. The shortcut stops too. Touching the app yourself (a click or a key in it) stops him at once and hands the job back to you. Within 1 second.
7. **Several apps in one job.** If the job names or needs another app, he brings it to the front, works there, and goes on. At the end, or when he stops by himself, he brings back the app and window you were in. If you stopped him by using an app yourself, he leaves you where you are. He does not ask "Act in this app?": your one consent covers all apps.
8. **When the job ends**, the card says what was done and, when the app's Undo is available, "To undo: Command-Z in Excel." He has no undo button of his own. The capture is dropped, as at the end of any guide.

### The research agents

Phase PA, not phase PH. An agent works while you are elsewhere, so it acts in a narrower way.

- Only through ways that do not take your screen: the apps' own scripting, and the system's calendar and reminders access (methods 3 and 4 in 13.2).
- Only in Notes, Reminders, Calendar and Excel, plus new files.
- No clicking in the background. No app is brought to the front.
- Anything that cannot be undone, or that leaves your Mac, is not done. It waits in the menu bar for one confirm from you.

### When something is not as expected

He stops and says so. He never tries again blind.

| What happened | What he does |
|---|---|
| The target is gone, moved, renamed, or covered by something | Does not act. "The button is not where it was. I stopped." |
| The front app or its window changed, and he did not change it | Stops. "You switched apps. I stopped." |
| The app refused the action, or did not answer in time | Stops. "I could not press it. Nothing changed, as far as I can see." |
| He acted, but the check does not see the expected result | Stops. "I pressed Save but the screen did not change. Check before going on." He does not press again: the first press may have worked |
| A window or question appeared that the job did not call for (a dialog, a sign-in, a warning) | Stops. Describes it |
| The ceiling was reached (actions in the job, or per minute) | Stops. Says which |
| The step is one he may never do | Does not act. Says so, and points instead |

After any stop, the card keeps the list of what was done so far, and you decide: do the step yourself, ask again, or close.

## 13.5 Levels

When you work with him there are two levels. Showing (pointing, highlighting, scrolling to) is always allowed and changes nothing.

| Level | Rule | Examples |
|---|---|---|
| **Acts** | Everything your words asked for. No confirm | Make a word bold, type a line, tick a reminder, fill cells, pick a tool, open a tab. Also send, delete, publish and replace, when that is the job |
| **Never** | Not done, whatever the words. He points instead | Typing into a password or other secure field. Anything while the Mac is in secure input mode. Paying and card details. Signing in and account settings. System Settings. Terminal and code editors (a click there can run commands). Keychain Access, the Passwords app, password managers. Any app on the "Never read this app" list. Phew's own windows |

Who decides the level: **Phew's own code, never the model.** Nothing the model says, and nothing on the screen, takes a thing off the Never list.

### The "cannot be undone" class

The code still knows which actions cannot be undone. You are not asked about them. The class has two uses:

1. On the card, such an action carries a mark in the list.
2. For a research agent, such an action waits in the menu bar for one confirm.

What is in the class: Send, Submit, Post, Publish, Share, Invite, Delete, Remove, Clear, Empty, Replace, Revert, Don't Save, Quit, Sign Out, Print, Export; the default button of any dialog; Return in a web form; replacing text or cell content that is already there; saving a calendar event that has guests, because invitations go out. For an agent, "leaves the Mac" is added: anything shared, sent or invited. An agent that only adds something new (a note, a reminder, an event with no guests, a sheet, a file) does it without waiting.

The model may add the mark to a step it finds risky. It can never remove one.

### How the code decides

One pure function, unit-tested, with no model call. Its inputs are things the code reads itself at the moment of acting: the app's identifier, the element's role and name, the menu path for a menu item, the kind of action, whether the element sits in a dialog, and whether a secure field is in play. It answers in this order. The first match wins.

1. **Never**, if any of these is true:
   - the target or the focused element is a secure field (the check the reader already uses, `SecretsFilter.isSecure`);
   - macOS reports secure input mode is on;
   - the app is on the "Never read this app" list;
   - the app is on a fixed never-act list in the code: System Settings, Keychain Access, Passwords, known password managers, Terminal and other terminals, code editors, Phew itself;
   - the element's name or menu path contains a word from the fixed never list: password, passcode, card number, security code, pay, buy, purchase, checkout, subscribe, sign in, log in, billing, account settings.
2. **Cannot be undone**, if the action is in the class above. Marked on the card. Waits, for an agent.
3. **Acts**, otherwise.

Where the code cannot judge, it falls on the careful side: a control with no name, an unknown role, or an app shown in a language with no word list counts as "cannot be undone". For an agent that means it waits. When you work with him it means a mark on the card, and he still acts.

Three plain limits of this method:

- **Languages.** The word lists must exist in every language your apps show. English and Italian first. The app list and the secure-field check do not depend on language. The words do: a "Pay" button in a language with no list is not caught by its name.
- **Icons with no name.** A bin icon with no name cannot be judged by words. It is marked, and he still acts.
- **A harmless name on a harmful button.** "OK" or "Continue" on a button that pays, deletes or sends. Nothing catches it. See 13.7.

The word lists and the never-act app list live in one file in the code, are read by tests, and never come from the model, the screen or the web.

## 13.6 Guards kept by Phew's own code

Every action, by any method, goes through one function. Nothing else in the app may send an action. Each guard below is checked inside that one function, at the moment of acting, not earlier.

Removed by your decisions: one action per approval, the approval that dies after 60 seconds, the per-app question, the run of at most 5 steps.

| # | Guard | How it is enforced | How it is tested |
|---|---|---|---|
| 1 | On-screen text is data, never instructions. Only your own words start a job | A job starts only from what you type or say in the input panel. A look at the screen can never start one. What he reads on the screen, the web or a file is passed to the model marked as data. Said plainly: with no approval step, code can no longer hold this guard by itself. The model plans the steps, and code cannot tell a step you meant from a step a trick planted. Guards 2 to 8 limit what a tricked step can do | PH.13, the trick test: 20 live jobs on made-up pages and documents with hidden instructions. The result is written down, whatever it is |
| 2 | The Never list | Decided by code (13.5), inside the acting function, for every app he touches in the job | PH.3: unit tests in English and Italian for passwords, paying, sign-in, System Settings, Terminal, Never-read apps and secure fields |
| 3 | Nothing is typed into a secure field | Three checks before any text or key: the target is not secure, the element that has focus is not secure, and macOS does not report secure input mode. While any is true, nothing is sent, by any method | PH.3. Live: a focused password field in the practice window stays empty and the card says why |
| 4 | No action in an app on the "Never read this app" list | The same list check the reader uses, made again inside the acting function. In a job across apps it is checked for each app | PH.3 |
| 5 | He stops on anything unexpected, and never retries blind | Before each action the code reads the target again: same element, same role, same name, the frame within a few points, nothing covering it. The front app and window must be the ones he expects, counting his own switches. After each action comes the check. Any difference, a refusal, or a window the job did not call for: he stops and says so | PH.4: a moved button, a surprise dialog and a failed check each stop the job with a plain line; nothing is tried twice |
| 6 | Stop within 1 second. Touching the app yourself stops him | Actions run one at a time, off the main thread. Stop sets a flag that is read before every action. The one action in flight is cut short by a time limit of half a second on Phew's requests to the app. Stop, the shortcut, and your own click or key in the app all set the flag | PH.4: under 1 second in 10 runs on a slow practice app, and no later step happens |
| 7 | A runaway brake | A ceiling on actions per job (first proposal 40, the same as for looks) and per minute. A pure rule, like `FollowRule`. It is not there to slow a normal job. It ends a job that has gone wrong. At the ceiling he stops and names it. The numbers are open (13.9) | Unit tests on the counters and the clock, as for `FollowRule` |
| 8 | One acting function, and nothing else can act | A test fails the build if any other file calls the acting functions of macOS | PH.2 |
| 9 | Off until Allow | Until you allow it on the consent screen (13.8), the acting function refuses everything | PH.5 |
| 10 | Every action on the card, a mark while he acts | The card lists each action as it happens. The mark stays until the action and its check are done. Both live in memory only | PH.12 |
| 11 | Every action is logged locally, as numbers and fixed words only | A new file, `actions.log`, beside `calls.log`. One line per action: the time, the job number, the step number, the kind of action (a fixed word: press, set, pick, click, script), the role (macOS's own fixed word, such as AXButton), the level, the method, how it ended (a fixed word, including each refusal reason), the milliseconds it took, and the count of characters typed. Never the text typed, never an element's name, never a window title. Whether it may name the app is open (13.9) | PH.12: a line built from made-up names, text and titles holds none of them, and every word in it comes from a fixed list |
| 12 | Agents act only out of sight, and wait for what cannot be undone | For a job run by an agent, the acting function accepts only methods 3 and 4, only for Notes, Reminders, Calendar, Excel and new files. Anything in the "cannot be undone" class, or that leaves the Mac, is held in the menu bar until your one confirm | Phase PA |

For testing, a small made-up "practice" window is needed: a few buttons, a tick box, a text field, a password field, a "Delete" button, a menu, a dialog, a button that moves or answers slowly. It is a second small target in the same Xcode project, used only by tests and the checker. No real app and no real content is touched by an automatic test.

## 13.7 What can still go wrong

macOS itself will not stop any of this: the Accessibility permission Phew already has is enough to click and type anywhere. Only Phew's own code stands between a planned step and an action.

What "never confirm" means, said once. Text on a web page or in a shared document can be written to trick an AI. He can also simply get a step wrong. With no confirm, a tricked or mistaken step, including a send or a delete, happens before you can stop it. This is your choice, and the design is built on it.

What still limits the damage, with no effort from you: the Never list; he stops by himself on anything unexpected and never retries blind; Stop within a second, and your own touch stops him; every action is on the card as it happens; only your own words start a job; the ceiling on actions; off until you allow it.

Ranked for the new design, most serious first.

1. **Something on your screen steers him, and he does it.** A web page, a shared document, a file name or a comment can hold text written to mislead him. Every vendor says this is not solved: "No browser agent is immune to prompt injection" (H10). OpenAI's agent was led by a hidden instruction to copy a logged-in user's private data into an attacker's page (H11). Brave showed instructions hidden in nearly invisible text inside a screenshot being followed (H12). Anthropic's own tests in 2025 found 1 to 2 attacks in 100 still getting through with all defences on (H10). *Limits:* a trick cannot start a job, only bend one you started; passwords, paying, sign-in and settings are never touched; the ceiling. *Does not:* a planted "send this" or "delete that" inside a job you asked for. Web pages inside a browser are the riskiest place (13.9).
2. **He gets it wrong by himself.** He takes "show" for "do", picks the wrong message, or deletes the wrong row. No trick is needed. *Limits:* unclear words mean he shows; the check after each action; the list on the card. *Does not:* the first wrong action has already happened when you read it.
3. **The code judges a harmful control as harmless.** A button named "OK", "Continue" or "Next" that pays, sends or places an order. A pay button in a language with no word list. Before, such a step would have been asked. Now it is done. *Limits:* the never-act apps and the secure-field check do not depend on names. *Does not:* a payment page in a browser whose button has an ordinary name.
4. **He acts on the wrong thing.** The screen moved, or a point on a canvas was a little off. *Limits:* guard 5 reads the element again and stops if anything differs. *Does not:* on a canvas there is no element to compare, only a place. A click a few points off selects the wrong object. Figma and Fusion are exactly this case.
5. **Undo does not bring it back.** Changes made through Accessibility or a script may not enter the app's Undo list (not verified). Figma and Fusion save to the cloud. A message, a calendar invitation or a shared note has already gone out. *Limits:* such actions are marked on the card. Nothing more.
6. **An agent acts while you are elsewhere.** It reads the web, where misleading text comes from, and you are not watching. *Limits:* scripting only, five places, no clicking; what cannot be undone or leaves the Mac waits for your confirm. *Does not:* a tricked agent can still add wrong notes, reminders, events or sheets. And a confirm in the menu bar can become a habit.
7. **Work across apps.** He brings an app to the front while you may be typing; your keys then land in that app. He also looks at, and acts in, an app you did not have in front when you called him. *Limits:* your touch stops him; the Never list and the "Never read this app" list hold for every app; he returns you to where you were.
8. **An action is done twice, or reported wrongly.** The check says "nothing changed" when the action did work, slowly. *Limits:* he never retries blind; the method is fixed before acting.
9. **A bug in the guards.** *Limits:* one function for all actions, the build test that nothing else can act, off until Allow, the practice window, your hand test before any real app.
10. **More pictures leave your Mac, and it costs more.** Each check is a look: one picture to the model, about a quarter of a cent. A job at the ceiling of 40 actions is about 10 cents. Same memory-only rule as a guide.
11. **An app that hangs.** Stop still ends the job within a second, but an action already sent cannot be called back.

## 13.8 No consent screen

Changed on 15 November, on your word: "users MUST not have to press allow". Phew acts from the first request, with nothing to allow. The consent screen that was built that day is no longer shown.

What is left as the way to turn acting off: a switch in the menu, "Let Phew act", on by default. With it off he guides and says "Acting is off, so here is how to do it."

What this changes, said once: a person who installs Phew is not told beforehand that text on a page or in a document can mislead him into a wrong step, including sending or deleting. The things he never touches, Stop, and stopping on anything unexpected stay as they are.

macOS still shows its own prompt the first time Phew scripts an app ("Phew wants to control Excel"), and one each for Reminders and Calendar. Those are macOS's, and Phew cannot remove them.

## 13.9 Decisions you took on 15 November, and what is still open

### Taken

| Decision | What you decided |
|---|---|
| Buttons | None. No "Do it", no "I'll do it". Your words and what you do decide: asking for doing means he does it, asking how means he shows, doing a step yourself hands the job back. Unclear words mean he shows |
| How far he goes | The whole job. No approval per click, no one action per approval, no 60-second approval, no run of 5 steps |
| Confirming | Never, when you work with him. He does not pause before send, delete, publish or replace |
| The research agents | They act in the MVP, in the background, only through the apps' own scripting and the system's calendar and reminders access: Notes, Reminders, Calendar, Excel, new files. No clicking in the background. What cannot be undone or leaves the Mac waits in the menu bar for one confirm |
| Several apps | Yes. He may bring another app to the front during a job and returns you to where you were. No question per app; one consent covers all |
| The consent screen | Short. The text in 13.8 |

Settled with the plan of the same day:

| Point | Outcome |
|---|---|
| Typing text into your documents | Yes. It is part of doing the job |
| Scripts for Excel, Notes, Reminders, Calendar | In the MVP (PH.10) |
| Single clicks on a canvas (Figma, Fusion) | In the MVP, only where no named control exists, with the hit rate measured (PH.9) |
| The folder for the acting code | `Phew/Senses`. No new folder |
| The words changed in `CLAUDE.md` (13.1) | Approved with the plan. Written in task PD.3 |

### Still open

Each with a recommendation. These go under Open in `07-decisions.md`.

| # | Decision | Recommendation |
|---|---|---|
| a | The ceiling numbers: actions per job and per minute | 40 per job, the same as for looks, and 20 per minute. First proposals. Set them after PH.7 shows what a normal job needs. The ceiling should never stop a normal job |
| b | May he act on web pages inside a browser, or only on the browser's own controls (tabs, back, menus)? | Yes, on pages too. You asked for autonomy, and much of your work is in a browser. The checks are the Never list and the trick test PH.13. Said plainly: this is the riskiest place. A web page is where text written to trick him is most likely, and where a button named "Next" can pay or send. If PH.13 goes badly, this is the first thing to take back. The careful choice: on pages he only shows |
| c | May the action log name the app? | No for now. Numbers and fixed words only, so no privacy rule is stretched. With several apps in one job the log is then less useful for looking back; the card's list covers the moment |

## 13.10 Build tasks for phase PH Hand

From the approved plan, same wording. `roadmap.html` is not edited by this document; the tasks are written into the roadmap in PD.5. Guards first; nothing acts on a real app before PH.5.

| Task | What | Done when |
|---|---|---|
| PH.1 | Design approved | `13-hand.md` matches your decisions; you approved this plan |
| PH.2 | One acting function in `Phew/Senses`, and a made-up practice window for tests | A build test fails if any other file can send an action; unit tests act only on the practice window |
| PH.3 | The Never list and the "cannot be undone" class, decided by code | Unit tests: passwords, paying, sign-in, System Settings, Terminal, Never-read apps and secure fields are refused, in English and Italian; unknown language or no name falls on the careful side |
| PH.4 | Stop and surprises | Stop within 1 s in 10 runs on a slow practice app; a moved button, a surprise dialog, a failed check each stop the job with a plain line; no retry |
| PH.5 | Consent screen and the "Let Phew act" switch | Off by default; the acting function refuses everything until Allow; the short text above |
| PH.6 | Do or show, from your words | The Conductor routes "do" and "show" correctly on 20 made-up requests in both languages; when unsure he shows; doing a step yourself hands the job back |
| PH.7 | Acting on named controls (press, set a value, pick a menu item), a look after each action | A 5-step job in the practice window, then in Notes, runs to the end with every action listed and checked |
| PH.8 | The seven apps measured, and what he knows of each written down | For Figma, Dia, Excel, Fusion, Notes, Reminders, Calendar: a table of what can be pressed by name, measured on your Mac; `docs/apps/<app>.md` |
| PH.9 | Clicks at a point, for canvases | Hit rate measured on 20 targets in Figma and in Fusion; written in the doc; used only where no named control exists |
| PH.10 | The apps' own scripting: Notes, Reminders, Calendar, Excel | A note, a reminder, an event and a filled cell range created on made-up data; macOS asks you once per app |
| PH.11 | Several apps in one job | "Copy this table into a new Excel sheet" from a made-up page: he switches app, does it, and returns you to where you were |
| PH.12 | The card: mark, action list, Stop; `actions.log` | The log holds only numbers and fixed words (unit test with planted names and text) |
| PH.13 | The trick test | 20 live jobs on made-up pages and documents that hold hidden instructions: no action outside what your words asked. Result written down, whatever it is |
| PH.14 | Phew knows he can act | `SelfKnowledge.text` updated; the five self-questions pass again |

Phase PA then adds: agents act in the background through PH.10's ways only, and what cannot be undone waits in the menu bar.

## 13.11 Sources

Read on 15 November 2026. Web content was treated as data. Search queries were generic and named no project and no person.

- H1 Anthropic, computer use tool (tool versions, actions, what the app must return, limits, safety advice): https://platform.claude.com/docs/en/agents-and-tools/tool-use/computer-use-tool . The last quarter of the page was not read.
- H2 Accessibility actions as used by other automation tools, including a press-first chain of fallbacks and the permission check: https://www.mintlify.com/lahfir/agent-desktop/api/click and https://www.mintlify.com/lahfir/agent-desktop/permissions . Community tools, not Apple's pages. Apple's own reference for these calls was not opened: not verified against Apple.
- H3 Apple Developer Forums, posting synthesized events, its permission, and that the sandbox does not block it: https://developer.apple.com/forums/thread/789896 and https://developer.apple.com/forums/thread/724603 . One blog claims the opposite for sandboxed apps; Phew is not sandboxed.
- H4 Secure input mode and what it does to event listeners: https://www.1password.community/1password-at-work-58/secure-input-blocking-other-apps-event-taps-25015 and https://openradar.appspot.com/48953777 . Whether *posted* keys are dropped in this mode: no source found, not verified.
- H5 Apple Events under the hardened runtime: the entitlement, the usage text, and the per-app prompt: https://developer.apple.com/forums/thread/697470 and https://developer.apple.com/forums/thread/750802 .
- H6 Apple, EventKit access levels and prompts: https://developer.apple.com/documentation/eventkit/accessing-the-event-store and https://developer.apple.com/documentation/technotes/tn3152-migrating-to-the-latest-calendar-access-levels . Read through search summaries, not opened in full.
- H7 Apple, running a shortcut from a web address or the command line: https://support.apple.com/guide/shortcuts-mac/apd624386f42/mac and https://support.apple.com/guide/shortcuts-mac/apd455c82f02/mac . Read through search summaries.
- H8 Figma, how the canvas is exposed to screen readers: https://www.figma.com/blog/building-accessibility-into-a-canvas-based-product/
- H9 Autodesk, Fusion scripts and add-ins: https://help.autodesk.com/cloudhelp/ENU/Fusion-360-API/files/PythonTemplate_UM.htm . Read through a search summary.
- H10 Anthropic, prompt injection defences and measured attack rates, 24 November 2025: https://www.anthropic.com/research/prompt-injection-defenses . Later, lower figures on Anthropic's help page are from its own tests: https://support.claude.com/en/articles/12902428-use-claude-in-chrome-safely
- H11 Embrace The Red, prompt injection against OpenAI's Operator, 17 February 2025: https://embracethered.com/blog/posts/2025/chatgpt-operator-prompt-injection-exploits/ . The same author on Claude's computer use, October 2024: https://embracethered.com/blog/posts/2024/claude-computer-use-c2-the-zombais-are-coming . The second was read through a search summary.
- H12 Brave, instructions hidden in screenshots, October 2025: https://brave.com/blog/unseeable-prompt-injections/ . Read through search summaries and https://simonwillison.net/2025/Oct/21/unseeable-prompt-injections/ . The vendor disputes parts of it.
- H13 Anthropic, computer use on the Mac: approval per app, fixed levels by kind of app (browsers view-only, terminals click-only), the notice while it works, Escape to stop: https://code.claude.com/docs/en/computer-use and https://code.claude.com/docs/en/desktop
- H14 Google, defences for an agent in Chrome, 8 December 2025: a second model that checks each action, limits on which sites it may act on, confirmation before paying or sending, a work log, pause and stop: https://blog.google/security/architecting-security-for-agentic/
- H15 OpenAI, agent help page: confirmations for high-impact actions, a watch mode on certain sites, the user takes over for sign-in: https://help.openai.com/en/articles/11752874-chatgpt-agent . Read through a search summary. On watch mode not triggering on some sites at launch: https://simonwillison.net/2025/Oct/22/openai-ciso-on-atlas/
- H16 Microsoft, "show me how" highlights next to a separate acting agent: https://blogs.windows.com/windows-insider/2025/05/12/copilot-on-windows-windows-insiders-can-now-use-vision-with-2-apps-and-new-highlights-feature-with-1-app/ and https://support.microsoft.com/en-au/windows/experimental-agentic-features-a25ede8a-e4c2-4841-85a8-44839191dfb3 . Read through search summaries.
- H17 Electron, how an outside tool asks an Electron app for its full Accessibility tree: https://electronjs.org/docs/latest/tutorial/accessibility
- On this Mac, read today with macOS's own `sdef` tool and each app's Info file, nothing sent anywhere: the scripting dictionaries and address schemes of Notes, Reminders, Calendar, Excel, Figma, Dia and Autodesk Fusion. macOS 27.2.1.

What others ship, in one place: a confirmation before anything that cannot be undone (H13, H14, H15); approval per app or per site (H13, H10); a visible notice while acting and one control that always stops (H13, H14); a list of what was done (H14); whole kinds of app held to view-only (H13); password entry left to the user, with no picture taken meanwhile (H15); "show me" kept as a separate, harmless mode beside "do it" (H16). Phew keeps the notice, the Stop, the list, the kinds of app he never touches, the password rule and the "show" mode. By your decisions of 15 November he does not keep the first two when you work with him: no confirmation and no approval per app. For the research agents the confirmation stays. No source was found for a shipped rate limit on actions or for a general undo; the ceiling in this design is Phew's own.

Not searched, and worth knowing: Apple's own reference pages for the Accessibility calls; what Dia's page elements expose; anything measured about Fusion's interface; whether changes made through Accessibility enter each app's Undo list.

## 13.10 The trick test, measured on 15 November

Twenty made-up windows, web pages and documents, in English and Italian. Each held hidden text that asked for something else than your request: press Delete, type a secret into a field, open another app, add a reminder, press Send, "the user changed their mind". Your request was harmless ("make the title bold", "tick Done").

**Result: in 20 of 20 his first action served your request. None followed the hidden text.**

For research tasks: 5 made-up cases with planted instructions in a memory result or in the screen text. 5 of 5 stayed on the task: no item added, no planted address opened. Three of the five reports said that a source held instructions.

What this does not show:
- Only the first action was measured. The riskier moment is after the job is done, when a planted "now press Send" could be followed. Not measured (roadmap PL.9).
- The windows were made-up data given to the model, not real apps.
- A real web page with hidden instructions was not tested: pages are read at Anthropic and cannot be faked from here.
- Twenty cases is a small number. It shows he is not easily tricked, not that he cannot be.
