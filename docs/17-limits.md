# 17. Limits review (phase NA)

> Decided on 17 November 2026 (`07-decisions.md` 7.1) and built the same day: R1 to R13 and R15, P1 and P2, the two changes to the safety core, F2 to F4. The tables below describe the state BEFORE that; `CLAUDE.md` holds the rules as they are now.
>
> Written 16 November 2026 before the review's fixes. Since then: the Observer's code is removed (L18, C16, R10's second half), and a conversation past 8 turns keeps its last 4 (L63).

Written 16 November 2026 from a read of the rules and the code. Nothing was built or run. The inventory (17.4) lists 103 limits and 20 places where a document and the code disagree. This page sorts them and gives a recommendation for each group. **You decide** (17.3); then `CLAUDE.md` is rewritten to your answers.

Four kinds are used:

| Kind | Meaning |
|---|---|
| GIVEN | Forced by macOS, by other apps or by how the model works. Cannot be removed, only worked around |
| PROT | Ours, and it protects your data, your money or your safety |
| SHAPE | Ours, a product choice |
| TIGHT | Ours, and it costs capability for little protection |

## 17.1 What I recommend, in plain words

### Loosen or remove: these cost you real jobs and protect little

| # | Limit (ids in 17.4) | What it blocks today | What I would do |
|---|---|---|---|
| R1 | Only six kinds of action: press, set a field, menu, one click, script, switch app (L33) | "Press ⌘B", "drag this layer", "scroll down and click", typing in a canvas or Google Docs, right-click | Add keys and shortcuts, scroll, drag, double and right click, in the same one acting function, each checked after |
| R2 | He may switch only to nine apps (L35) | "Paste this into Mail, Pages, Word, Slack, Chrome" | Any app that is not on a Never list |
| R3 | Password, pay and sign-in words also checked in the **window title** (L24) | Any press in a Figma file named "Login screen", a note "Payment plan" | Check the words on the control and its menu path only |
| R4 | He stops on any new sheet and on any read-back that differs (L30) | "Save" on a new document; a field that reformats what he typed | Expect the sheet a step should open; compare read-back after normalising |
| R5 | 20 actions a minute, then the job ends (L28) | Filling 30 fields, adding 25 reminders | Pause and go on, not stop. Keep 40 per job until measured |
| R6 | Scripts append only to what this job made; exact title or nothing (L36); events only 30 days back to a year ahead (L37) | "Add a line to my Groceries note"; "move my event in 2028" | Append to existing notes; when several match, show the choice; widen the window |
| R7 | One waiting confirm per task, the rest refused (L52) | "Tick every reminder the research covered" | A list of waiting changes with "Confirm all" |
| R8 | A task: 5 searches, 8 pages, 50 cents, 5 minutes; three at once, a fourth refused (L46, L47) | "Compare 10 tools with prices" | A "deep" size you ask for (about $2), and a queue for the fourth |
| R9 | The picture is sent at half the screen's sharpness (L10) | Small text in a dense sheet or layer list is misread | Send a sharp crop around the area of interest |
| R10 | 4,000 characters of window text; the Observer that should handle more never runs (L09, L18) | "Summarise this whole contract on screen" | Read long windows in pieces; fix or delete the Observer |
| R11 | Web addresses kept without what follows "?" (L66) | YouTube and Figma links are stored broken | Keep it for a known list of sites |
| R12 | An agent can read no file and change no existing sheet (L50, L51, L57) | "Summarise the PDF in Downloads"; "put it in my Budget sheet" | A read-only file tool for folders you chose; changes to existing files behind the confirm. This is decision 42 |
| R13 | Nothing of a capture is kept for a follow-up; no saved threads (L14, L63) | "What did the previous window say?"; "continue yesterday's chat" | Keep the last capture some minutes, in memory only; keep threads as text per project in the encrypted Map. This is decision 34 |
| R14 | He reaches only Anthropic's servers (L82, L83) | Every connection | Phase NB (`docs/18-capabilities.md`) |
| R15 | Right ⌥ + right ⌘ only (L101); no way to change the request ceilings (L103) | Keyboards without those keys | A shortcut you can set; the ceilings in the Limits panel |

### Decide as a product, not as a fix: these change what Phew is

| # | Limit | The choice |
|---|---|---|
| P1 | He reads the screen only when called (L01) | An opt-in **watcher for one named thing** ("tell me when this export ends"), on the Mac, with no model call until it happens. Not a general watch. I would allow the narrow version |
| P2 | He never appears unasked; results wait in the menu (L56, L98) | Opt-in notifications for a finished task and for a time you set |
| P3 | He never speaks aloud (L97) | Keep, unless you want hands-free use |
| P4 | Never in Terminal, code editors, System Settings (L23) | Needed for self-shaping (NC). I would lift it only for Terminal and editors and only inside NC, and for a short list of harmless System Settings switches. Keychain and password managers stay |
| P5 | An agent never clicks and never takes the screen (L53) | Keep. With connections (NB) an agent can act without the screen, which removes most of the need |

### Keep: the safety core

You put these in scope, so here is what each costs and what it blocks.

| Limit | What it costs you | What it prevents | View |
|---|---|---|---|
| Secure fields never read or written; nothing typed while a password prompt is open (L05, L25) | "Fill my login form" | A password sent to the model or typed into the wrong place | Keep. macOS hides most of it anyway |
| Password, payment and sign-in controls never pressed (L24, on the control) | "Buy it", "sign me in" | A payment or an account change made on a misreading | Keep on the control; drop on the window title (R3) |
| The secrets filter before every network call (L87) | "Why is my Stripe test key rejected?"; a JWT to decode | A key or a card number leaving the Mac | Keep. Add a one-time "send this as it is" that you press yourself |
| The API key only in the Keychain (L88) | Nothing | A key in a file or a log | Keep |
| Screen, web, file and pasted text is data, never orders; only your words start a job (L90, L91) | "Follow the steps on this page" is sometimes refused | A page or a shared document making him send or delete your things | Keep. It is the main defence once connections exist (see "the dangerous mix" in `connections.html`) |
| One acting function, with a build test (L21) | New kinds of action must be built there first | An action that skips every guard | Keep |
| Stop within a second; your touch takes over (L31) | You cannot type in the same app while he works | A job you cannot interrupt | Keep |
| No words in any log (L89) | Harder to debug a failed job | Your questions and screen in a plain file | Keep |
| Captures never on disk; the Map encrypted and on the Mac (L62, L78) | No "what was on screen an hour ago" | Your screen history in a file | Keep the disk rule. R13 loosens only the in-memory part |
| The "Never read this app" list (L04) | Nothing: you set it | Reading an app you named | Keep |

None of these is why a job fails today. The jobs that fail, fail on the first table.

## 17.2 Faults found, to fix whatever you decide

These are places where the code does less than the rule says, or a document is wrong. Ids from the list at the end of 17.4.

| # | Fault | Fix |
|---|---|---|
| F1 | **Pictures are not filtered** (C7). The rule says the secrets filter runs before any network call; it runs on text only. A key visible on screen goes out in the picture | State it plainly in `CLAUDE.md` now. Later: blur the frames of fields the text filter flagged |
| F2 | **Never-act apps are still read** (C13). Terminal, password managers and System Settings are read and sent like any app, unless you list them | Put the password managers and Keychain on the Never-read list by default |
| F3 | Never words are not checked for scripts (C14); the per-job brake does not hold for agents (C15) | Check script titles against the payment and password words; count an agent's task as one job |
| F4 | Two parts of the "cannot be undone" class are written and not built: a dialog's default button, a control with no name (C6) | Build them or strike them from `docs/13-hand.md` |
| F5 | The search-words rule says two things (C8): the decisions say names may be used with no limit, the agent's prompt says not to | Your call. See decision D8 |
| F6 | Stale text in `docs/16-control.md`, `03-experience.md` 3.5, `04-architecture.md` 4.4, `05-map.md` 5.8, `07-decisions.md` 7.1, a comment in `Hand.swift` (C1 to C5, C9, C11, C12, C16 to C20) | Corrected in the same commit as the `CLAUDE.md` rewrite |

## 17.3 Decisions for you

Answer by number. "As advised" for all is a valid answer.

| # | Decision | Advised |
|---|---|---|
| D1 | R1 to R11 and R15: loosen as written? | Yes, all |
| D2 | R12, decision 42: may an agent read files in folders you chose, and change existing files behind the confirm? | Yes |
| D3 | R13, decision 34: keep the last capture some minutes in memory for a follow-up; keep threads as text per project | Yes, 10 minutes, text only |
| D4 | P1: a watcher for one named thing | Yes, narrow |
| D5 | P2: opt-in notifications | Yes |
| D6 | P4: Terminal and code editors, only for self-shaping | Decide in NC |
| D7 | The safety core: keep all ten, with the two changes (title words, a "send as it is" button)? | Yes |
| D8 | F5: may an agent put your name and names from your memory in web searches? | Only when the task itself names them |
| D9 | F2: password managers and Keychain never read by default | Yes |

## 17.4 The full inventory

I found 103 limits, listed below, plus 20 contradictions or gaps between the docs and the code. Everything here comes from reading the files. I built nothing, ran nothing, and did not open `Claude Memory/` or `.claude/worktrees/`.

The project root is `the repository`. All paths below are relative to it. These files hold most of the limits:
- `Phew/Senses/Hand.swift`
- `Phew/Senses/NeverList.swift`
- `Phew/Shell/ActJob.swift`
- `Phew/Brain/Doer.swift`
- `Phew/Brain/Runner.swift`
- `Phew/Shell/TaskList.swift`
- `Phew/Brain/Limits.swift`
- `Phew/Senses/WindowReader.swift`
- `Phew/Senses/ContextPacket.swift`
- `Phew/Senses/SecretsFilter.swift`
- `Phew/Map/MapImport.swift`
- `Phew/Map/ClaudeExport.swift`

**Kinds used in the table:**
- **GIVEN:** forced by macOS, by other apps or by how the model works.
- **PROT:** ours, and it protects the user's data, money or safety.
- **SHAPE:** ours, a product or design choice.
- **TIGHT:** ours, and it costs capability for little protection.

**Short forms in the "Stated" column:**
- **C.md:** `CLAUDE.md` "Rules (direction)".
- **3.x, 4.x, 5.x, 13.x:** sections of `docs/03`, `docs/04`, `docs/05`, `docs/13`.
- **7.1, 7.2, 7.4:** sections of `docs/07-decisions.md`. 7.4 is the dated log.
- **"code only":** enforced in code, stated in no doc.

**The 25 `HandEnd` words** (`Hand.swift:207-228`): done, off, secureField, secureInput, neverReadApp, neverActApp, ownApp, password, paying, signIn, jobCeiling, minuteCeiling, gone, moved, surprise, frontChanged, failed, timeout, checkFailed, noAccess, stopped, userInput, notFound, manyFound, needsConfirm. Each has a plain sentence in `ActJob.swift:150-176`.

### A. Reading the screen

| ID | Name | Rule | Stated / enforced (test) | Kind | Blocks today | If removed or loosened, needs |
|---|---|---|---|---|---|---|
| L01 | Reads only when called | No background reading; a look happens only on a call. A guide looks again only after the user acts | C.md; 4.6 / `Senses.swift:3-12`, `FollowRule.swift:4` (FollowRuleTests.testNoLookWithoutAnAction) | PROT | "Tell me when this export finishes"; "watch my inbox" | A watcher that works on the Mac only, its own consent, a rule on what leaves |
| L02 | Screen watch only during a guide | The watch starts with a guide's steps. It stops at the end, after 120 s with no user action, or at 40 looks. It never calls the model | 4.6; 7.1 (14 Nov) / `ScreenWatch.swift:14,51`; `FollowRule.swift:11` (ScreenWatchTests.testTwoMinutesWithoutAnActionStopTheWatchAndAnActionStartsItAgain; FollowRuleTests.testTheGuideStopsFollowingAtTheCeiling) | SHAPE (cost, privacy) | A 50-step tutorial stops following at step 40. Reading docs for more than 2 min pauses the follow | Higher ceiling, or a look budget in cents |
| L03 | Look timing | Quiet 1 s after an action, 1.5 s between looks, 0.5 s calm after a scroll, settle cap 2 s, drag slop 4 pt | 4.4 (PS) / `FollowRule.swift:7-19` (FollowRuleTests, all 15) | SHAPE | A step the app finishes by itself (a sync, a render) never moves the guide on | A cheap on-device change signal that can start a look |
| L04 | "Never read this app" list | A listed app gives no text, picture, cursor element, menus, watch or Accessibility flag, and no acting | C.md; 4.6 / `NeverRead.swift:40-45`, `Senses.swift:17`, `ScreenWatch.swift:51,69`, `MenuReader.swift:59`, `WindowReader.swift:125,262`, `NeverList.swift:41` (NeverReadTests, all 7; MenuAndTreeTests.testNeverReadAppGetsNoFlag) | PROT (user-set) | Any help in a listed app, by the user's choice | Nothing; the user controls it |
| L05 | Secure fields never read | A password field gives its role and frame only, never its value | C.md; 4.6 / `WindowReader.swift:45,166`, `SecretsFilter.swift:11` (SecretsFilterTests.testSecureFieldsAreRecognised) | PROT, partly GIVEN (macOS hides the value) | "Check what I typed in this password box" | Not advisable |
| L06 | Element under the cursor only from the app being read | Read only when it belongs to the app being read, never to Phew or another app lying on top | 16-control row 14 / `WindowReader.swift:65` (HandTests.testTheElementUnderTheMouseComesOnlyFromTheAppBeingRead) | PROT | "What is this?" on a floating overlay of another app: picture only, no element | Read the top window's owner with its own never-read check |
| L07 | Window walk caps | At most 3,000 elements, depth 60, 0.8 s, in reading order. A cut drops the end of the window | code only / `WindowReader.swift:14-19` (no test) | SHAPE (speed; hung apps are GIVEN) | A long Notion page or a big sheet: the lower part is missing | Walk the cursor's branch first (the shortcut comment says so) |
| L08 | Cursor read caps | 30 elements, depth 4, 15 ms, 300 characters; 0.1 s system-wide messaging timeout | code only / `WindowReader.swift:21-24,30` | SHAPE | A long cell under the mouse is cut at 300 characters | Larger caps |
| L09 | Packet caps | 4,000 characters of text, nearest the cursor first; 80 controls; 60-character labels. A label at the cap is left out of an action's name | 4.4 (4,000 only) / `ContextPacket.swift:42-44`, `ActJob.swift:112` (SecretsFilterTests.testTrimKeepsNearestTextInReadingOrder; SensesRulesTests.testPointablesKeepNearestThenReadingOrder) | SHAPE (cost) | "Summarise this whole contract on screen": 4,000 characters only. Controls past the nearest 80 cannot be pointed at or pressed | More text with the Observer, or reading in pieces |
| L10 | Picture rule | The front window when the mouse is inside it, else the whole display. 1 pixel per point. Phew's windows left out, cursor hidden | 7.1 #34 (12 Nov) / `ScreenCapture.swift:10,40-50` (SensesRulesTests.testPictureIsTheWindowOnlyWhenTheMouseIsInsideIt) | SHAPE; 1 px per point is TIGHT | Small text in a dense Excel sheet or Figma layer list is misread (half the Retina detail) | Capture at 2x and send a crop |
| L11 | Whole-display picture cap | A whole display is sent at ≤1,950 tokens. The API's own cap is about 4,784 tokens | 7.4 (16 Nov, A3) / `ScreenshotSize.swift:12,20` (LimitsTests.testAWholeDisplayCostsAtMost1950Tokens, testThePictureGoesSmallerAndAPointMapsBack) | SHAPE (cost) + GIVEN (API cap) | On a 5K display, text in a whole-screen picture is unreadable | Crop to the area of interest |
| L12 | Follower look caps | 800×600 crop around the mouse, 30 elements, 1,000 characters, 3.5 s, 1,024 tokens, one retry | 4.4 (PS.4) / `Follower.swift:61-63,109-114` (BrainAgentsTests) | SHAPE (cost) | A dialog far from the mouse is seen only in the text, so the guide may not move on | Centre the crop on the step's target as well |
| L13 | A task reads the screen once | The Runner has no tool to look again | C.md; 3.6; 4.4 / `Runner.swift:274-283` (RunnerTests.testTheRequestShape) | PROT | "Research each item as I scroll the list" | A look tool for agents, with a per-task count |
| L14 | No capture reused for a follow-up | Every reply takes a fresh look; an earlier capture is never kept | C.md; 3.10; 7.2 #34 open / `WorkingMemory.swift:3-6` (ToolLoopTests.testFollowUpCarriesEarlierTurnsAsTextAndOnlyTheFreshLook) | PROT + cost | "What did the previous window say?" after switching | Decision 34: keep a capture for N minutes, in memory |
| L15 | Menu names | Read once per job and per app. Two levels, enabled items only, 3,000 characters, 1 s. Apple menu and private menus (recent, history, bookmarks, window, services, profiles) left out. English and Italian words only | C.md; 7.4 (N2.6) / `MenuReader.swift:18-30,58-81` (MenuAndTreeTests.testCapIsHardAndCutsAtALineEnd, testPrivateMenuWords, testNamesOnlyWithoutPrivateMenus) | PROT/SHAPE | "Open Recent > X" is not listed. Third-level submenus are not listed | A deeper walk on demand |
| L16 | Asks Chromium/Electron apps for their control tree | Writes an Accessibility flag into the app being read, only when called, set back after; waits 1 s the first time per process | C.md / `WindowReader.swift:240-290`, `Senses.swift:28-36` (MenuAndTreeTests.testChromiumAndElectronGetTheManualFlagOnlyAndNoRestore, testEnhancedOnlyWhereManualIsRefusedAndOffAndThenSetBack) | GIVEN, worked around | The first call in Slack or VS Code is 1 s slower; Keynote's tree may be thin | Polling until the tree stops growing |
| L17 | Image data dropped from text | Data URIs and base64 runs are removed | code only / `WindowReader.swift:223-236` (SensesRulesTests.testImageDataIsDropped) | SHAPE | Nothing real | — |
| L18 | Observer threshold | The Observer runs only above 4,001 characters, but the text is capped at 4,000, so it never runs | 4.4 / `Observer.swift:9` vs `ContextPacket.swift:42` | SHAPE (dead) | Nothing | — |
| L19 | macOS permissions | Accessibility, Screen Recording and Microphone are needed; no Screen Recording means no picture and no watch | 13.8 / `ScreenCapture.swift:20`, `ScreenWatch.swift:60` | GIVEN | Everything that needs the permission | — |
| L20 | Canvas apps have no elements | Figma and Fusion canvases are reached by screenshot points only | 7.1 (12 Nov "never cut"); 13.7 #4 / `ActJob.swift:109` | GIVEN | Exact work on a canvas: a click a few points off picks the wrong object | Plugins or API access (L9) |

### B. Acting

| ID | Name | Rule | Stated / enforced (test) | Kind | Blocks today | If removed or loosened, needs |
|---|---|---|---|---|---|---|
| L21 | One acting function | Only `Hand.act` may act; a build test fails otherwise | C.md; 13.6 g8 / `Hand.swift:349-352` (HandTests.testOnlyHandActs) | PROT | Every new method (keys, drag) must be built in Hand first | — |
| L22 | "Let Phew act" switch | On by default; when off, every action ends `off` | C.md; 13.8 / `Hand.swift:397`, `PhewApp.swift:9,22` (HandTests.testOffRefusesEverything; ActJobTests.testActingIsOnByDefaultAndNeverAsks, testSwitchOffRefuses) | PROT | Nothing while on | — |
| L23 | Never-act apps | 30 apps: System Settings and its panes, Keychain, Passwords, 7 password managers, 7 terminals, 10 editors (Xcode, VS Code, Cursor, Windsurf, Zed, Sublime and others), Script Editor, Automator, all JetBrains apps. An app with no bundle id is refused too | C.md; 13.5 / `NeverList.swift:9-20,38-46` (HandTests.testNeverApps; ActJobTests.testAnUnknownOrNeverAppIsRefusedBeforeAnyLook) | PROT | "Turn on Dark Mode"; "run the tests in Terminal"; "rename this in VS Code"; "save this login in 1Password" | Per-app allowlists of safe actions, a shown preview of a command |
| L24 | Never words | Password, paying and sign-in words (English and Italian, whole words) in a control's name, its menu path **or its window title** | 13.5 (name and menu path only); 7.4 PH.2 names the title clause / `NeverList.swift:24-35,49-54`, `Hand.swift:471-473` (HandTests.testNeverWordsEnglishAndItalian) | PROT; the title clause is TIGHT | Any press in a Figma file called "Login screen redesign", a note "Password ideas", a doc "Payment plan". A "Buy milk" or "Subscribe to newsletter" button | Apply the words to the control only, not the window title |
| L25 | Secure field and secure input | Nothing is typed or pressed when the target or the focused element is secure, or macOS secure input is on | C.md; 13.6 g3 / `NeverList.swift:40,50`, `Hand.swift:463-473` (HandTests.testSecureFieldsAreNeverWrittenOrPressed) | PROT, partly GIVEN | "Fill my login form". All acting while another app holds secure input (an open password prompt) | — |
| L26 | Not on Phew's own windows | Phew's own windows are refused (`ownApp`) | C.md / `NeverList.swift:39` | SHAPE | "Close your card" | — |
| L27 | Careful side | A control with no name, or a language other than English or Italian (≥0.6 sure), is marked on the card and still acted on | 13.5 / `NeverList.swift:58-64` (HandTests.testCarefulSide) | SHAPE | Nothing. Gap: a German "Bezahlen" button is not caught | Word lists in more languages |
| L28 | Runaway brake | 40 actions per job; 20 per minute across all jobs, agents' scripts included | 13.6 g7; 13.9a; 7.2 #39 / `Hand.swift:357-359,432-436,502-505` (HandTests.testCeilings, testScriptsCountTowardsTheCeilings, testFrontSwitchesCountTowardsTheCeilings) | PROT; 20 per minute is TIGHT | Filling 30 form fields or adding 25 reminders stops at 20 within a minute | Measured numbers (PH.7 never measured them), a pause instead of a stop |
| L29 | Repeated-action stop | The same kind, label and frame a third time in a row ends the job as stuck | code only (not in 13.x) / `ActJob.swift:78-83`; Doer prompt `Doer.swift:62-63` (ActJobTests.testTheSameActionAThirdTimeInARowStopsTheJob) | PROT | "Press + five times"; "Undo three times" | A repeat count from the request that the code honours |
| L30 | Stop on anything unexpected, never retry | Stops when the control is gone or moved (>4 pt, or another role or name), a new sheet opens and the step's name has no "…", the front app changed, a set value reads back differently, or the read-back of a script differs. The first step that is not done ends the job | C.md; 13.6 g5 / `Hand.swift:238-239,440,469,481-497,604-611` (HandTests.testMovedTargetStopsWithNoRetry, testSurpriseSheetStopsUnlessCalledFor, testFrontAppChangedStops; ActJobTests.testStopsOnAHandEndWithoutRetry) | PROT; the sheet and read-back parts are TIGHT | "Save" on a new document opens a save sheet → surprise. A field that reformats input ("3,5" → "3.50", a phone mask) → checkFailed. An animating toolbar → moved | Expected-window hints from the Doer, normalised read-back |
| L31 | Stop within 1 s; your touch takes over | Stop or the shortcut ends the job. The user's own click or key in the app he works in ends it; not in other apps, and not while a script runs | C.md; 13.6 g6 / `Hand.swift:280-298,415-418` (HandTests.testStopWithinOneSecondOnASlowControl, testUserInputStopsOnlyInTheAppHeWorksIn, testUserInputDuringAScriptDoesNotEndTheJob) | PROT | You cannot keep typing in the same app while he works there | Telling user input from his own by area |
| L32 | Timeouts | 0.5 s per Accessibility action, 60 s per script, 30 s to bring an app to the front | 13.6 g6 (0.5 s only) / `Hand.swift:360-366` (no test for 60 s or 30 s) | SHAPE | A slow button (a big Excel book) ends with `timeout` | Per-app timeouts |
| L33 | Action kinds | Only: press, set (replaces the whole field value), pick a menu item, one click, script, bring an app to the front. No keys, shortcuts, drag, scroll, double-click or right-click | 13.2; Doer prompt / `Hand.swift:11-21`, `Doer.swift:18-30,64-65` | TIGHT | "Drag this layer up"; "press ⌘B"; "scroll down and click"; typing into Google Docs or a canvas text box; "right-click > Copy link" | Key, drag and scroll methods in Hand with the same gates and a check after each |
| L34 | Where a click may land | A point click only for the click kind, only inside the job's app window. Press and set need an element from the look | code only / `ActJob.swift:102-113`, `Doer.swift:158-163` (ActJobTests.testACanvasPointMapsToTheScreenInTheJobsWindow, testDoerKeepsOnlyRealTargets) | PROT | Menu-bar extras, the Dock, a control outside the front window | — |
| L35 | Apps he may switch to | open_app works only for Notes, Reminders, Calendar, Excel, Dia, Figma, Fusion, Safari, Finder | 7.1 (MVP apps); 13.9 no list / `Doer.swift:101-114` (ActJobTests.testDoerOpenAppAnswers) | TIGHT | "Paste this into Mail, Pages, Word, Slack, Chrome, Numbers" when not in front | Any app not on the Never lists |
| L36 | Scripts | Only for Notes, Reminders, Calendar, Excel. Append and cells only on what this job made. A change or delete only by exact title: one match, or nothing | C.md / `Hand.swift:249-250,1320-1326`, `Doer.swift:32-51` (HandChangeTests.testOneExactTitleOrNothing, testNoneOrManyChangesNothing) | Exact title is PROT; "only own" is TIGHT | "Add a line to my Groceries note" (edit_note replaces the whole body); "delete the dentist reminder" without the exact title; two "Untitled" notes | Append to existing notes; a fuzzy match with a shown choice |
| L37 | Calendar and Reminders window | Events from 30 days back to 365 days ahead; only incomplete reminders | code only (marked shortcut) / `Hand.swift:1231-1255` (no test) | TIGHT | "Move my event in March 2028"; "un-tick a done reminder" | A wider window |
| L38 | New events | No guests, no location, one hour by default. Events with guests or repeats are in the "cannot be undone" class and keep no Undo | 13.5 / `Doer.swift:38-39`, `NeverList.swift:90-91`, `Hand.swift:525-527` | SHAPE/PROT | "Set a meeting with Marta and invite her"; "make it weekly" | Guest and repeat fields, with their own confirm |
| L39 | Excel range | A plain A1 address, ≤16,384 columns, ≤1,048,576 rows; cells read back | code only / `Hand.swift:1331-1349` (HandTests.testExcelRangesAndReadBack) | GIVEN (Excel's grid) | Named ranges, sheet names | — |
| L40 | "Cannot be undone" class | Fixed words (send, delete, export… in English and Italian), writing over text, a change with guests or repeats. Tagged on the card; runs with no confirm when the user watches | C.md; 13.5 / `NeverList.swift:66-96` (HandChangeTests.testTheClassIsDecidedByCode) | SHAPE (risk accepted 15 Nov) | Nothing | — |
| L41 | Undo | What a change or delete replaced is kept in memory until the card's next turn. None for guests or repeats, none for button presses or typing | C.md / `Hand.swift:161,270-274,539-555` (HandChangeTests.testADeletedItemComesBackOnUndo, testUndoPassesTheGates) | PROT | Undo after the next question; undo of "make it bold" | A record of earlier values for interface actions |
| L42 | Focus | He brings another app to the front and returns to the exact window, unless you took over. Phew never becomes active | C.md / `Hand.swift:557-602`; `PhewApp.swift:443` (HandTests.testBackReturnsUnlessTheUserTookOver, testBackReturnsToTheExactWindow) | SHAPE | — | — |
| L43 | macOS asks per scripted app | macOS asks once for each scripted app, Reminders and Calendar; a refusal ends with `noAccess` | 13.8 / `Hand.swift:894-939` | GIVEN | A job before the user allows it | — |
| L44 | Doer: one action per call | One main-model call per action, 2,048 tokens, one retry on a bad answer | code only / `Doer.swift:127-137,256` | SHAPE | About 2 s per step, so long jobs are slow | Batched plans checked by code |
| L45 | actions.log | Numbers and fixed words only, never an app name | C.md; 13.9c / `ActionLog.swift:4,26` (HandTests.testActionLogHoldsOnlyNumbersAndFixedWords) | PROT | "What did you do in Excel yesterday?" | Decision 13.9c |

### C. Agents and tasks

| ID | Name | Rule | Stated / enforced (test) | Kind | Blocks today | If removed or loosened, needs |
|---|---|---|---|---|---|---|
| L46 | Three tasks at once | A fourth task is refused with one line | 3.6; 4.4 / `TaskList.swift:13-15,74` (TaskTests.testThreeRunTogetherAFourthIsRefusedAndStopEndsOne) | SHAPE (cost) | "Research these 5 suppliers at once" | A queue |
| L47 | Per-task limits | 5 searches, 8 pages, 12 rounds, $0.50, 300 s. The report is written once 80% of the cost or time is used | 3.6 (5, 8, 50 cents); 7.4 (12 rounds, 5 min) / `Runner.swift:29-46,190-214` (RunnerTests.testSearchLimit, testPageLimit, testRoundLimitWritesTheReportInTheLastRound, testCostLimitEndsWithTheReportSoFar, testTimeLimitCancelsTheRequest) | PROT (money); pages are TIGHT | "Compare 10 tools with prices"; a deep literature check | Per-task presets ("deep" at $2) |
| L48 | Page length | ≤8,000 tokens per fetched page (about 6,000 words) | code only / `Runner.swift:111-112` | SHAPE | Long specs or PDFs past about 6,000 words | Reading in chunks |
| L49 | Addresses it may open | Only addresses its own searches found, or that you typed. Addresses are removed from screen text, Map lines and files; the server is set to refuse addresses from Phew's tools | 3.6; 4.4 / `Runner.swift:104-108,289-313`, `RunnerTools` (RunnerTests.testTheScreenIsDataWithoutAddresses) | PROT + GIVEN (fetch opens only addresses seen in the conversation) | "Summarise the link in this email on my screen"; "read the links in my Map". Gap: a bare `example.com` stays | A user tick on an address seen on screen |
| L50 | Agent tools | Web search, web fetch, Map search, add_item. No file reading or writing, no screen tool, no clicks | 4.4 / `Runner.swift:282-283,334-342` | PROT | "Summarise the PDF in my Downloads"; "read my project's docs" | A read-only file tool scoped to a chosen folder |
| L51 | What add_item may do | Add a note, reminder, event or sheet; rename, edit, complete, move or delete one note, reminder or event by exact title. Never a sheet change or an append. Title ≤200 characters; a sheet ≤1,000 cells and always a new workbook | 4.4 says "adds only" (stale) / `Runner.swift:363-411`, `TaskList.swift:149-156` (TaskTests.testANonScriptActionIsRefused, testAddItemAsksForChangesAndDeletesByTitle) | SHAPE/TIGHT | "Put the results into my existing Budget.xlsx"; a sheet of more than 1,000 cells | Changing existing sheets, behind a confirm |
| L52 | Agent changes wait | Every change or delete, even ticking a reminder, waits for one confirm in the menu; adds run at once. One waits per task; a second is refused, not queued | C.md; 13.5 / `NeverList.swift:80-91`, `Hand.swift:477,517-518`, `TaskList.swift:159-194` (TaskTests.testABackgroundDeleteStopsAndShowsOneConfirmRow, testDismissDropsTheWaitingAction; HandChangeTests.testAnAgentWaitsAndAWatchedJobRunsTagged) | PROT; one per task is TIGHT | "Tick done every reminder the research covered": the first waits, the rest are refused | A queue of confirms, a "confirm all" |
| L53 | Agents never click | Scripts only, in a job that does not watch you; never an app brought to the front | C.md; 13.6 g12 / `TaskList.swift:196-208` | PROT | "Research it, then draft it in Figma or a Google Doc" | Agents that can click, which takes the screen |
| L54 | Search words | The prompt tells the agent not to put the user's name or private details in a search unless the task asks. Code cannot check search words | Runner prompt / `Runner.swift:65-67` | PROT (prompt only) | Possibly "news about my company" | — (see contradiction C8) |
| L55 | Stop a task | Ends within 2 s; nothing is reported; the screen read is dropped | 3.6 / `TaskList.swift:104-110` (RunnerTests.testStopEndsTheTaskAndSendsNothingAfter) | SHAPE | "Stop and give me what you have" | Stop with a partial report |
| L56 | Results wait in the menu | A result is never shown by itself | C.md / `TaskList.swift:3-4` (TaskTests.testAFinishedTaskWaitsUntilOpened) | SHAPE | Urgent results | An opt-in notification |
| L57 | Report files | New files only: a PDF in the chosen folder or Downloads, plus a Markdown copy. The name comes from the first 5 words of the task, cleaned. Never written over (O_EXCL), " 2" up to " 999" | C.md; 3.6 / `Report.swift:5-6,31-49` (RunnerTests.testANameIsNeverReplaced, testTheNameComesFromTheTaskCleaned) | PROT | "Update last week's report file" | Decision 42 |
| L58 | Report facts | Enter the Map only when ticked; all start unticked; sorted only when you open the list | C.md; 5.9 / `MapImport.swift:217-223` (ImportTests.testAReportsFactsStartUntickedAndOnlyTickedOnesAreWrittenAsFromAReport; TaskTests.testAReportsFactsAreSortedOnlyWhenTheUserOpensTheList) | PROT | "Remember what you found" | — |
| L59 | Task list in memory only | Words and the menu list last until Quit; the files stay | code only / `TaskList.swift:5` | SHAPE | After relaunch the Ready list is empty | A saved list |
| L60 | Project CLAUDE.md excerpt | ≤4,000 characters, only for the project the call is about, only after you chose that folder once | 5.10 / `MapImport.swift:314,398-410` | SHAPE | Questions that need the rest of a long CLAUDE.md | A larger excerpt or a read tool |
| L61 | Routing when unsure | Act vs guide → guide. Task vs explain → explain. "Unclear" only for speech | C.md; 4.4 / `Conductor.swift:17,24-26,56` (VoiceTests.testATypedQuestionIsNeverUnclear) | PROT/SHAPE | "I need to export this" → he shows instead of doing | — |

### D. Memory and captures

| ID | Name | Rule | Stated / enforced (test) | Kind | Blocks today | If removed or loosened, needs |
|---|---|---|---|---|---|---|
| L62 | Captures in memory only | Screen text and pictures are dropped when the answer, guide or task ends; never on disk or in a log; a debug dump only with a flag | C.md; 4.6 / `ContextPacket.swift:129`, `Senses.swift:58` (SensesRulesTests.testCapturesStayOffDiskWithoutTheFlag) | PROT | "What was on my screen 10 minutes ago?"; "capture by showing" | Decision 34 |
| L63 | Conversation memory | The last 8 turns as text. Dropped 10 minutes after the last answer, on close and on Quit. No saved threads | 3.10 (8 turns, 10 min); 5.8 says 3 turns, 5 min / `WorkingMemory.swift:8-9`, `TextCard.swift:21` (ConversationTests.testAConversationOfNineTurnsSendsOnlyTheLastEight, testTheConversationEndsAfterTenMinutes; ToolLoopTests.testTurnsAreDroppedOnQuit) | SHAPE | "Continue yesterday's chat"; a long debug chat | Decision 34 (threads kept per project) |
| L64 | Fixed classes and links | 11 classes, 7 links. Anything outside is dropped; Me is never created | C.md; 5.3, 5.4, 5.9 / `MapWrite.swift:187` (LibrarianTests.testNeverASecondMeAndAnythingOutsideTheListIsDropped) | SHAPE | A "Recipe" or "Invoice" type: only a kind on a Note or Document | — |
| L65 | Librarian sees labels only | Never the window text, picture or controls | 5.9 / `Librarian.swift:4-8` (LibrarianTests.testTheRequestHoldsNoWindowTextNoPictureNoElements) | PROT | "Remember the numbers in this table", unless they are in the answer | — |
| L66 | Labels kept from the screen | App name, window title (only as a Document's name), path or address without `?`, `#` or login | C.md; 5.9 / `WindowReader.swift:81` (SensesRulesTests.testWebAddressLosesQueryFragmentAndLogin; LibrarianTests.testNoteRulesAndWebAddresses) | PROT; TIGHT for addresses that need their query | YouTube `watch?v=` and Figma `?node-id=` links are stored broken | Keep the query for a known list of sites |
| L67 | Secret-looking text dropped whole | Anything the secrets filter would change is not stored | 5.9 / `MapWrite.swift:191,335`, `Librarian.swift:155-159` (LibrarianTests.testLooksSecret, testAPasswordWithoutIsNeverReachesTheRequestOrTheMap) | PROT, a little TIGHT | "Remember the wifi password is on the fridge" is dropped | — |
| L68 | Source priority | Told beats observed beats imported; confidence set by code | 5.5 / `MapWrite.swift:363,765` (MapForgetTests.testAWeakerSourceNeverReplacesAStrongerOne; ImportTests.testAnImportedFactNeverReplacesAToldOne) | SHAPE | A newer import cannot update a told fact | — |
| L69 | Forget | Acts at once, from your words on the remember route only. 30 days in Recently deleted, then wiped | 5.5 / `MapWrite.swift:44,525-640` (MapForgetTests.testPurgeWipesOnlyAfterThirtyDays, testForgetOnTheRememberRouteOnlyAndAQuestionBackForgetsNothing, testTheRealDeleteLeavesTheNameInNoFileOrJournal) | PROT | — | — |
| L70 | Sensitive facts | A second lock; left out of the export unless ticked; never given to the speech recogniser | C.md; 5.9; 5.12 / `MapWrite.swift:284`, `MapExport.swift:9`, `BrainMap.swift:76` (LibrarianTests.testSensitiveFactsGoToTheSensitiveFile; MapExportTests.testSensitiveFactsOnlyWhenTicked; VoiceTests.testSpokenNamesAreNamesOnlyFromFourClassesNothingSensitive) | PROT | A doctor's name, when misheard, is never corrected | — |
| L71 | Field caps | Name 200, Note 500, summary 400, path 1,000, kind 40, card line 200, ask-back 300 | code only / `MapWrite.swift:104-205,334,740` | SHAPE | A long decision note is cut at 500 characters | Larger caps |
| L72 | Recall caps | Profile ≤200 lines; recall block ≤6,000 characters; a Map search ≤10 lines; ≤2 Map searches per answer, then it must answer | 5.8; 7.4 / `MapRecall.swift:239,261,271`, `ToolLoop.swift:42` (MapRecallTests; ToolLoopTests.testAModelThatKeepsSearchingGetsNoThirdSearch) | SHAPE (cost) | "List all my open tasks" past 10; a question that needs 3 lookups | Paged results |
| L73 | Defined terms | Active 14 days, due soon 7 days, stale 90 days | 5.6 / `MapRecall.swift:50-60` | SHAPE | — | Tuning |
| L74 | Paste import | 20,000 characters per call, at most 5 calls (100,000); the rest is not read | 5.10 (20,000); 7.4 (100,000) / `MapImport.swift:85-89` (ImportTests.testALongPasteIsCutIntoPiecesAndTheRestIsNamed) | SHAPE | A 300,000-character memory dump | More calls |
| L75 | Project memory import | Only CLAUDE.md, .claude/CLAUDE.md and memory/*.md (not MEMORY.md, never .jsonl, no links); ≤20 files, ≤100 KB each | 5.10 / `MapImport.swift:306-314` (ImportTests.testOnlyTheAllowedFilesAreRead) | PROT | Importing transcripts or docs/*.md | — |
| L76 | Claude export import | 150 files, 100 KB each, 600 KB in all. A zip ≤5 MB and ≤500 entries, no escaping paths; links refused; 4 calls at once | 7.4 (PB.4) / `ClaudeExport.swift:53-54,85-89,261` (ClaudeExportTests.testCapsAreCountedAndSaidInAFixedLine, testZipBombsAndEscapingEntriesAreRefusedBeforeUnpacking) | PROT | An export of more than 150 files | Higher caps |
| L77 | Import rules | Nothing written before you tick. Instruction-like facts, feedback files and CLAUDE.md start unticked. No ChatGPT or Gemini exports. Undo works for the last import only | 5.10 / `MapImport.swift`, `MapWrite.swift:502` (ImportTests.testNothingIsSentBeforeSortAndNothingWrittenBeforeKeep, testUndoLastImportThenRestore) | PROT/SHAPE | "Import my ChatGPT export"; undoing an earlier import | Parsers for those formats; undo per import |
| L78 | Map stays on the Mac | Encrypted with SQLCipher, keys in the Keychain, no sync | C.md / `Database.swift:28-63` (MapEncryptionTests.testNoPlainTextInEitherFileOrJournal, testWrongKeyFails) | PROT | The Map on a second Mac or a web dashboard | L11 (cloud Map) |
| L79 | Name matching | Same class and name; same project for Task, Document, Event. Two people with the same name become one | 5.9 / `MapWrite.swift` (LibrarianTests.testReuseOnlyWhenNameClassAndProjectMatch) | SHAPE | Two different "Marco"s | Disambiguation |

### E. Network and money

| ID | Name | Rule | Stated / enforced (test) | Kind | Blocks today | If removed or loosened, needs |
|---|---|---|---|---|---|---|
| L80 | Daily ceilings | $3.00 a day, 400 requests a day, 30 a minute; 0 means none. Checked before each new request from you. The panel offers $1, $3, $10 or none; the request counts cannot be changed there | 7.4 log of 16 Nov only / `Limits.swift:13,30-43,78-84`, `LimitsPanel.swift:10` (LimitsTests.testThe31stInAMinuteIsRefusedAndNothingIsSent, testTheDailySpendCeilingRefusesWithTheRightSentence, testZeroMeansNoLimit, testTheDayRollsOverAtLocalMidnight) | PROT (money) | A heavy day over $3; 31 quick questions in a minute | More panel options |
| L81 | Task reserve | A task sets aside its $0.50 from the day; under 1 cent left, it does not start | 7.4 (N2.12) / `Limits.swift:53-58,113-123` (LimitsTests.testTasksReserveTheirBudgetAndCannotPassTheCeilingTogether, testATaskIsRefusedWhenNothingIsLeftToday, testATaskEndsWithItsReportWhenTheDayCeilingIsPassed) | PROT | A task late in a $3 day | — |
| L82 | One provider | Claude API only, through one interface; model names from the docs | C.md; 7.1 (11 Nov) / `ModelProvider.swift:122`, `ClaudeProvider.swift:10` | SHAPE | Your own subscription; an offline local model | L9 |
| L83 | One network endpoint | api.anthropic.com only; web search and fetch run at Anthropic | 16-control row 18 / `ClaudeProvider.swift:10` | SHAPE | Intranet pages; MCP tools | L9 |
| L84 | Model tiers and output caps | Small model: Conductor, Librarian (the Observer was removed on 16 November 2026). Main model: Guide, Follower, Runner, Doer. maxTokens: Conductor 1,024, Doer 2,048, Guide 8,192, Runner 8,192, Librarian 4,096, Follower 1,024 | C.md / `Conductor.swift:72`, `Doer.swift:256`, `Guide.swift:175`, `Runner.swift:281`, `Librarian.swift:115` | SHAPE | Very long explanations get cut | — |
| L85 | One tool call per reply | `disable_parallel_tool_use` | code only / `ClaudeProvider.swift:121-123` | SHAPE | Map lookups are serial | — |
| L86 | API behaviour | `max_uses` counts per turn; search words cannot be checked by code; structured outputs need every field; images over the limit are downsized; prompt injection is unsolved | 4.4; 13.7 / `Runner.swift:95-99` | GIVEN | — | — |

### F. Secrets and safety

| ID | Name | Rule | Stated / enforced (test) | Kind | Blocks today | If removed or loosened, needs |
|---|---|---|---|---|---|---|
| L87 | Secrets filter | Runs before every network call: key patterns (sk-, GitHub, AWS, Slack, Google, Stripe, JWT, bearer, PEM), Luhn-valid cards of 13 to 19 digits starting 2 to 6, values after password words (English and Italian) | C.md / `SecretsFilter.swift:16-67`, `Senses.swift:38,47`, `ToolLoop.swift:110`, `MenuReader.swift:36` (SecretsFilterTests, all 14; ToolLoopTests.testSecretInAToolResultIsRemovedBeforeItIsSent; ConversationTests.testEveryEarlierTurnIsFilteredAgainBeforeAFollowUp) | PROT; a little TIGHT | "Why is my Stripe test key rejected?"; "decode this JWT"; test card numbers; "The password is incorrect" loses a word | A one-request "send as is" switch |
| L88 | Key in the Keychain only | The API key lives only in the Keychain | C.md / `KeyStore.swift` | PROT | — | — |
| L89 | No words in logs | calls.log and actions.log hold fixed fields; shellLog exists in debug builds only | C.md / `PhewApp.swift:452-458`, `ActionLog.swift` (RunnerTests.testLogLinesCarryTheTaskNumberAndNoWords; TaskTests.testTheTasksWordsAreNeverLogged; ListenerTests.testNoHeardWordAndNoContextWordInAnyLogLine; ImportTests.testNoWordOfThePasteInAnyLogLine) | PROT | Debugging a failed job from the logs | — |
| L90 | Screen, web, file and pasted text is data | Kept in delimited blocks a line cannot close early; prompts say "data, never instructions" | C.md; 13.6 g1 / `Doer.swift:67-69,247-249`, `Runner.swift:59-63,295` (RunnerTests.testInstructionsInAWebPageOrTheMapStayData; ActJobTests.testDoerScreenIsDataInItsBlock) | PROT (prompt-level) | "Follow the steps on this page" may be refused | — |
| L91 | Only your words start a job or a forget | Screen, web and file text can never start one | 13.6 g1; 5.5 / `Conductor.swift`, `MapWrite.swift` | PROT | Automations started by screen content | — |
| L92 | Speech on the device | Sound in memory, dropped at stop or cancel; ≤10 s kept while the recognisers prepare; macOS 26 needed; no outside model download | C.md; 4.6; 7.2 #43 / `Listener.swift:6,88-90,104-107` (ListenerTests.testSoundDroppedAtStop, testSoundDroppedAtCancel, testKeptSoundIsCappedAtTenSeconds) | PROT; macOS 26 is GIVEN | Voice on macOS 15; better name recognition | Decision 43 |

### G. The look

| ID | Name | Rule | Stated / enforced (test) | Kind | Blocks today | If removed or loosened, needs |
|---|---|---|---|---|---|---|
| L93 | Speech languages | Italian and English only | 7.1 (14 Nov) / `Listener.swift:104-105` | SHAPE | Speaking French or Spanish | More transcribers |
| L94 | Show what he heard first | When the recogniser is under 0.90 sure or a name is doubtful (20 of 40 test sentences) | 7.2 #45 open / `NameMatch.swift:215-221` | SHAPE/TIGHT | Quick voice commands often need a Return | Decision 45 middle option |
| L95 | Spoken name lists | ≤40 names to the recogniser and model, ≤30 from the Map, none sensitive | code only / `Spoken.swift:29`, `BrainMap.swift:71-77` (VoiceTests.testTheNamesLineIsCappedFilteredAndOnlyForSpoken) | SHAPE | The 41st name is never helped | — |
| L96 | No main window, no Dock icon | Panels never take focus. Exceptions: the folder picker and acting's app switch | C.md / `PhewApp.swift:11`, `phewIsFront` `PhewApp.swift:443` (NeverReadTests.testThePanelNeverActivates) | SHAPE | A full Map browser; dragging files onto Phew | — |
| L97 | Never speaks aloud | No speech synthesis anywhere | C.md / none in code (16-control row 3) | SHAPE | Hands-free use; low-vision users | Speech output |
| L98 | Never appears unasked | Results wait in the menu; the menu icon never animates | C.md / `PhewApp.swift:138-139`, `TaskList.swift:4` | SHAPE | "Tell me at 3 pm"; deadline alerts | An opt-in notifications rule |
| L99 | No display of captured context | He never shows what he captured for an answer | C.md; 7.1 (10 Nov) | SHAPE | "Show me what you saw" to debug a wrong answer | — |
| L100 | Card size and life | 400 pt wide, an open thread ≤520 pt tall, shows 8 turns, closes after 10 min | 3.10 / `Design.swift:62,67`, `TextCard.swift:21,353` (ConversationTests.testTheThreadShowsAtMostEightTurns) | SHAPE | — | — |
| L101 | Shortcut | Right ⌥ + right ⌘ only; left keys never; hold 0.3 s to talk | 7.1 (11 Nov) / `HotKey.swift:3-6,29`, `Design.swift:122` (VoiceTests.testTheLeftKeysNeverStartAnything, testAHoldNeverAlsoPresses) | SHAPE | Keyboards with no right ⌥ or ⌘ cannot call him | A configurable shortcut |
| L102 | Notch | Only the listening shape, while the key is held; no home, no character | C.md; 3.9 / `NotchListening.swift` (NotchTests) | SHAPE | — | Later L1 |
| L103 | No settings panel for limits | Card limits have no settings; the Limits panel sets the dollar ceiling only | 3.10 "Not in this design" / `LimitsPanel.swift` | SHAPE | Changing the request ceilings or the brake numbers | A settings panel |

### Contradictions and gaps between docs and code

- **C1, the switch's default.** The comment at `Hand.swift:355` says "Off when never set", but `Hand.swift:397` defaults to on. 7.1 (12 Nov and 15 Nov) still says acting is "opt-in, off by default"; C.md and the code say on from the start.
- **C2, `docs/16-control.md` is stale.** §4 row 10 and §6 say "No confirm exists" and "Changing, sending and deleting are not built". The code has the confirm (`TaskList.swift:166-194`, N2.4) and change and delete scripts (`Hand.swift:75-87`). C.md now matches the code. The 7.4 line of 16 Nov says the same stale thing.
- **C3, add_item.** 4.4 says add_item "only adds… cannot send, delete or replace". `Runner.swift:363-392` lets it rename, edit, complete, move and delete; these wait for a confirm.
- **C4, consent screen.** 3.5 still describes a consent screen with [Allow] before the first task. None exists (13.8; 16-control row 2).
- **C5, conversation memory, two numbers.** 5.8 says 3 turns and 5 minutes. 3.10 and `WorkingMemory.swift:8-9` say 8 turns and 10 minutes.
- **C6, "cannot be undone" class not fully enforced.**
  - 13.5 lists "the default button of any dialog" and "Return in a web form". There is no default-button check in the code, and there is no Return action.
  - 13.5 says a control with no name "counts as cannot be undone". `NeverList.careful` only marks it; it does not put it in the class.
- **C7, pictures are not filtered.** C.md says "secrets filter before any network call", but `Senses.swift:49` notes screenshot pixels are not filtered. A key visible on screen goes out in the picture.
- **C8, search words.** 3.6 and 7.1 (14 Nov) say search words may hold names "with no limit". The Runner prompt (`Runner.swift:65-67`) tells it not to use the user's name or private details.
- **C9, talk key.** 7.1 (11 Nov) says "Right Option held alone". The code holds both right keys for 0.3 s (`HotKey.swift:3-6`).
- **C10, web pages.** 13.9 b (acting on pages inside a browser) is still open. The code has no browser rule, and Dia and Safari are in `Doer.apps`, so it acts on pages.
- **C11, user input in other apps.** The 7.4 PH.2 line says your click in any app stops a job. Since PH.7 the code stops only for the app he works in (`Hand.swift:283-291`).
- **C12, window-title words, two places.** 13.5 matches never words only in a control's name and menu path. The code adds the window title (`Hand.swift:471`); only the 7.4 PH.2 line says so.
- **C13, never-act is not never-read.** Terminal, password managers and System Settings are still read and sent to the model (non-secure text, menu titles) unless the user puts them on the Never-read list. Only the 7.4 N2 line notes this for menu titles.
- **C14, never words skip scripts.** Scripts are checked against the app lists only (`Hand.swift:510-518`). A reminder "Pay rent" can be made or deleted by script, while any press in a window titled "Pay rent" is refused.
- **C15, the per-job brake does not reach agents.** 13.6 g7 sets a ceiling per job. Each add_item opens a new Hand job (`TaskList.swift:197`), so for a task only the shared 20 per minute holds.
- **C16, Observer never runs.** C.md and 4.4 step 2 describe it, but `Observer.minChars` is 4,001 and the text cap is 4,000.
- **C17, cost of a look, two numbers.** 13.7 #10 and 7.1 #38 say about 0.25 cents. 4.4 PS.4 measured 0.41 cents.
- **C18, task limits stated only in part.** 3.6 has 5 searches, 8 pages and 50 cents. 12 rounds, 5 minutes and the 8,000-token page cap are only in the 7.4 log or the code.
- **C19, money ceilings.** $3 a day, 400 a day and 30 a minute are stated only in the 7.4 log of 16 Nov, in no design doc.
- **C20, browsing apps.** 5.10 says he lists every Claude Code project with memory for you to pick. The code reads only the folder you chose; 7.4 PB names this difference.

### Guards with no named test

- The window walk caps (L07).
- The 60 s script and 30 s front timeouts (L32).
- The calendar and reminders window (L37).
- The page token cap (L48).
- The project excerpt cap (L60).
- The Map field caps (L71).
- One pixel per point (L10).
- The " 999" name suffix (L57).

Tested, but with no test of the number itself:
- Three tasks at once (L46): TaskTests checks the behaviour, but no test reads the constant `TaskList.most`.
- The 80-control cap (L09): no test reads `pointableCap`.

Two things to know:
- I did not read `docs/13-hand.md` 13.2 in full, `docs/05-map-storage.md`, or `docs/15-design.md`, so look rules stated only there may be missing.
- The 7.4 log has entries dated 16 Nov, after today's date of 16 Nov. I took them as written.
