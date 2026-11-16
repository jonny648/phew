# 16. Last control of the project

Done on 16 November 2026 by the checker, on version 0.1.0 (commit `49821e5`). Read only: no build, no test, no app run, no model call. Everything below comes from reading files and from `git` and `gh` commands. Where a point needs a run to be proven, it says so.

## 1. Local folder

Looked at: `ls -la`, `git status --short --ignored`, `git ls-files`, `du`, `git worktree list`.

169 files are tracked by git. Nothing secret-looking is tracked.

| Item | What it is | Size | Judgment |
|---|---|---|---|
| `Phew/` | The app code: Shell, Senses, Brain, Map, icon | 1.3 MB, 80 files | Fine |
| `PhewTests/` | 33 test files | 560 KB | Fine. Made-up data only (checked in section 2) |
| `Phew.xcodeproj/` | The Xcode project | 36 KB | Fine. Holds your Apple team id (`QX33NG5Y25`), normal for an Xcode project |
| `Phew.entitlements` | The app's permissions file | 4 KB | Fine |
| `docs/` | The plan, research, decisions and design | 808 KB, 36 files | See section 3 |
| `roadmap.html` | The checklist | 68 KB | Fine |
| `CLAUDE.md`, `README.md`, `CHANGELOG.md` | Rules, front page, change list | 12, 4, 4 KB | `CLAUDE.md` has lines that no longer match (section 4). `CLAUDE.md` shows as changed and not committed (the lead is editing it) |
| `Tools/` | Practice app, disk image script, icon scripts | 32 KB | Fine |
| `.github/workflows/ci.yml` | Build and test on GitHub at each push | 4 KB | Fine |
| `.claude/agents/` | The five roles | 5 files | `shell.md` line 18 named the consent screen (fixed after this control, section 3) |
| `.claude/worktrees/` | Work folders of earlier sessions | 4 MB (`bugfix` 1.2 MB, `feature` 2.8 MB) | Ignored by git. Two are left, both marked locked. `feature` is in use by this session. `bugfix` sits on its own commit `8b859bd`. Decide before removing |
| `Claude Memory/` | Your real exported memory | 232 KB | **Ignored and untracked, confirmed** (`.gitignore` line 10; `git ls-files` shows 0 files). Not opened |
| `.git/` | History | 3.0 MB | See section 2 for what the history holds |
| `.DS_Store` | Finder file | 14 KB | Ignored. Fine |
| `roadmap-next.html` | A new file, not tracked, not ignored | not measured | Not written by the checker. Decide to commit or remove |
| `default.profraw` | Test leftover | 168 KB | Was there, ignored by `*.profraw`. Already gone when I looked: being removed |
| 18 `worktree-agent-*` branches | Leftover branches | none | Already gone when I looked: only `main`, `worktree-bugfix`, `worktree-feature` remain |

Nothing large is tracked. The `.gitignore` covers `.DS_Store`, `xcuserdata/`, `build/`, `DerivedData/`, `*.profraw`, `*.profdata`, `.claude/worktrees/` and `Claude Memory/`. Nothing found that should be ignored and is not, except `roadmap-next.html` if it is only a draft.

Outside the folder (not read, named in `07-decisions.md` line 197): the encrypted Map, its Keychain keys, the API key, the settings and the logs stay on your Mac on purpose.

## 2. Online

Looked at: `gh repo view`, `git rev-parse`, `git tag`, `gh release view v0.1.0`, `gh run list`, and a search of the tracked files (not history).

| Check | Result |
|---|---|
| Repository | `jonny648/phew`, **private**, default branch `main` |
| Last push | 16 November 2026, 05:20 UTC |
| Local HEAD against `origin/main` | Same commit: `49821e5b8f389e5f850cb3a8c47d11d0bde1c1af` |
| Tag | `v0.1.0` exists |
| Release | `v0.1.0`, published 16 November 05:21 UTC, not a draft, not a pre-release |
| Release file | `Phew-0.1.0.dmg`, 3.78 MB, uploaded, 0 downloads |
| Last runs of "Build and test" | Latest two green (58 s and 1 m 10 s). Two earlier runs failed (the compiler on GitHub found a closure ambiguous; the workflow file had a fault), both fixed |
| Tests on GitHub | The tests that open a window do not run there (`roadmap.html`, PG.4). So the green check proves the build and most tests, not all |

Personal data in the tracked files (search for email, phone, home path, names, links):

| What | Where | Judgment |
|---|---|---|
| Bundle id with your name, `com.gianlucatroietto.Phew` | `Phew.xcodeproj/project.pbxproj` lines 335, 370, 390, 410; `Phew/Brain/KeyStore.swift:7`; `Phew/Shell/PhewApp.swift:397`; `PhewTests/ClaudeClientTests.swift:146`; `docs/05-map-storage.md` lines 101, 171; `docs/07-decisions.md:26` | Fine in a private repository. Before it goes public: your name is then public in every place. Changing it would also change the Keychain service name, so your stored keys would not be found |
| Apple team id `QX33NG5Y25` | `Phew.xcodeproj/project.pbxproj` lines 240, 289 | Fine in a private repository. Not a secret, but ties the code to your Apple account |
| Your GitHub login `jonny648` | `docs/00-now.md:46`, `docs/07-decisions.md:197`, `roadmap.html` line 324 | Fine. Public anyway once the repository is public |
| Figma file links (two files in your team) | `docs/10-research-market.md:11`, `docs/15-design.md:7`, `docs/07-decisions.md:176`, `docs/archive/review.html:358` | Fine in private. Before public: the links point at your private Figma drafts, so drop or keep them on purpose |
| Email address | none real. Only made-up ones: `printer@example.com` (`Phew/Brain/BrainSelfCheck.swift:655`), `mario.rossi2026@studenti.university.it` (`PhewTests/SensesRulesTests.swift:66`) | Fine |
| Phone numbers | only made-up ones in `PhewTests/SecretsFilterTests.swift` lines 43, 97 | Fine |
| Home paths | only `/Users/someone/...`, `/Users/made-up/...`, `/Users/student/...` in tests and one self-check (`Phew/Map/LibrarianSelfCheck.swift:127,129`) | Fine. None holds your user name |
| Real names of people | none found. Made-up names only | Fine |

In the history (not in the files): all 98 commits carry the author name and a Mac address. 66 use `gianlucatroietto@gmail.com`, 15 use `gianlucatroietto@Mac-di-Giann.local`, 17 use `gianlucatroietto@192.168.1.4`. `07-decisions.md:197` already says so for the Gmail one. **Should go before the repository is made public**: either rewrite the history with a neutral author, or publish a fresh repository with only the code (the plan already allows this, L8). Not a problem while it stays private. No key was found in the files (`sk-ant` appears only as a made-up value in tests); the history scan at PG.2 said the same.

## 3. Docs

**Fixed on 16 November 2026, after this control.** Of the 38 stale lines found, 30 are corrected and 8 are left, for the reasons in the table. 18 more lines with the same old statements, which the control had not listed, were corrected in the same files.

Looked at: every file in `docs/` against `docs/README.md`, then searched for words that mark old states (consent screen, off by default, not built yet, notch, separate phase PX).

**Index.** Missing from `docs/README.md` before this control: `15-design.md`, `hand.html`, `validation.html`, `apps/`, `archive/choices.html`. They were added, with a line for this file. The three index lines that said "to be rewritten after PD.3" (`01-foundation.md`, `02-vision.md`, `08-b2b-targets.md`) now say they were rewritten on 15 November.

**Contradictions with `CLAUDE.md` or the code as built.** Each fix changes one sentence; no section was rewritten.

| File | Lines fixed | Lines left, and why |
|---|---|---|
| `docs/README.md` | 3 (the index lines above) | 0 |
| `docs/00-now.md` | 2 listed (built through PG; the four things are built), 2 more (the date; a pointer to `roadmap-next.html`) | 0 |
| `docs/01-foundation.md` | 1 listed, 1 more (the risk line that said `13-hand.md` was not written and acting was off by default) | 0 |
| `docs/02-vision.md` | 2 listed (the notch), 5 more ("being built" in the values and jobs tables) | 0 |
| `docs/03-experience.md` | 3 listed, 3 more (three other mentions of the consent screen, in 3.5 and 3.6) | 0 |
| `docs/04-architecture.md` | 3 listed (notch row; no consent screen; no `read_project_memory`, the Runner's fourth tool is `add_item`, which only adds) | 0 |
| `docs/05-map.md` | 5 listed (the excerpt in the request, not a tool; recall is built) | 0 |
| `docs/05-map-storage.md` | 1 | 0 |
| `docs/06-sprint.md` | 2 | 0 |
| `docs/07-decisions.md` | 0 | 4 (parking list, lines 116, 117, 118, 121). This file was outside the task that made the fixes: the lead keeps it. Still stale |
| `docs/10-research-agents.md` | 0 | 1 (line 58). A dated research record; its own header says the design documents count where they differ |
| `docs/13-hand.md` | 4 listed, 5 more (other lines that said "off until Allow" or "one consent") | 0 |
| `docs/14-company.md` | 2 | 0 |
| `docs/15-design.md` | 1 listed (section F now says it is not in the app), 1 more (the menu drawing) | 3 (lines 84 to 86). The study of 15 November describes the screens as they were that day; line 7 of the file already says so |
| `.claude/agents/shell.md` | 1 listed, 1 more (the description line) | 0 |

(Count: 27 of the 35 listed lines fixed, plus the 3 index lines = 30 of 38. Left: 8.)

Seen while fixing and not changed, for the lead to decide:
- `.claude/agents/brain.md` lines 18 and 20 still give the Guide and the Runner the tool `read_project_memory`, and say no Runner tool writes anything. Both are old: the Runner has `add_item`.
- `docs/02-vision.md` line 25: "When voice input is built (P6), he answers to phew, few, phiu, pheoo". Voice is built; nothing in the code answers to a name.
- `docs/13-hand.md` line 237 and `docs/03-experience.md` 3.6 keep "waits in the menu bar for one confirm" for an agent. It is the decision, and `CLAUDE.md` says the same, but no confirm is built (section 4, rule 10).
- `docs/05-map.md` line 345 ("not checked yet... when building PB.4") and the caching and "remember" bullets under 5.11 still speak from before the build; the new sentence above them says all of it is built.
- `docs/14-company.md` 14.1 still says 217 tests and 1.7 cents a question.
- `docs/03-experience.md` 3.5, lines 55 to 65, still gives the text of the research consent screen as "the screen's text". That screen is not shown (log of 15 November: "PA.2 no longer has a consent screen").

**Checked and in line with the built product:** `docs/07-decisions.md` 7.1 and 7.4 (a long log; older rows keep old decisions as history, which is right), `docs/13-hand.md` 13.8, the voice and notch rows of the log, the L18 text in the roadmap, `docs/apps/*.md`, and the PB import of Claude's export (`05-map.md` 5.10 says at line 355 that it changed). Agents (PA), PH and PX as one phase, and acting on by default are right in `CLAUDE.md`, the roadmap and `13-hand.md` 13.8.

## 4. Rules

Looked at: `CLAUDE.md` Rules (direction), then the code and the tests. I read; I did not run. "Not checkable by reading" means only a run or a use can show it.

| # | Rule | True today? | Evidence | Where the log names a bend |
|---|---|---|---|---|
| 1 | Four things, in this order | Yes | Routes in `Conductor.swift`, `Doer.swift`, `Guide.swift`, `Runner.swift`, Map in `Phew/Map` | none needed |
| 2 | No main window or Dock icon; small panels allowed; **"and the consent screen shown at your first task"** | Bent. The panels part is true. **The consent screen part no longer matches**: no consent screen is shown. The code is left in `TextCardActing.swift:90` (`ActConsent`) as a flag only | `SetupPanel.swift`, `MenuPanels.swift`; `TextCardActing.swift:94` says it is never shown | 7.4: 15 Nov "Acting is now on from the start"; 15 Nov PX.5 "unused consent screen code is removed" (a small part is still there) |
| 3 | He never speaks | Yes | No speech synthesis anywhere in `Phew/` (searched for `AVSpeechSynthesizer`, `NSSpeechSynthesizer`) | none needed |
| 4 | Never appears unasked; results wait in the menu bar | Yes by reading | `TaskList.swift` line 121 "waiting in the menu"; `TaskTests.testAFinishedTaskWaitsUntilOpened` | none needed. Not seen by use |
| 5 | Reads the screen only when called; guide watch; looks after his own action | Not checkable by reading | `ScreenWatch.swift`, `ScreenWatchTests`; `Senses.swift` | 7.4: 15 Nov PS (watch during a guide, named); 15 Nov (looks after own action, named) |
| 6 | An agent reads once, the Map, the web, a typed address, the project's `CLAUDE.md`; saves new files only | Yes by reading | `Runner.swift`, `Report.swift` (never over an existing file), `RunnerTests` | 7.4: 15 Nov PA |
| 7 | Acts on the Mac from your words, no confirm; **acting on from the start**; switch "Let Phew act" | Yes | `Conductor.swift` routes "act"; `Hand.allowedKey` default on; `ActJobTests` | 7.4: 15 Nov (word "users must not have to press allow") |
| 8 | Never-list decided by code: passwords, paying, sign-in, System Settings, Terminal and editors, password managers, Never-read apps, own windows | Yes | `NeverList.swift`; `HandTests` (English and Italian) | none needed |
| 9 | One acting function; a test fails the build otherwise; Stop in 1 s; every action on the card | Yes | `HandTests.testOnlyHandActs` (line 697); live: stop at 103 ms (log 15 Nov, PX.4); `ActionLog.swift` | 7.4: 15 Nov PH.2 (one named exception: reads the full tree) |
| 10 | Background agent acts only out of sight; **"Anything that cannot be undone or that leaves your Mac waits in the menu bar for one confirm"** | The first half is true. **The confirm is not built**: an agent can only add (note, reminder, event, sheet); no code path asks for a confirm (searched `Runner.swift`, `TaskList.swift`, `Hand.swift`) | `Runner.swift`, `Hand.swift`; roadmap PA.4 and L18 | 7.4: 15 Nov "in this phase an agent only adds"; roadmap L18 keeps the confirm for later. **This line of `CLAUDE.md` no longer matches** |
| 11 | Web, file and pasted text is data | Yes by reading, plus live tests | `Runner.swift` prompt; 5 of 5 and 20 of 20 trick tests (log 15 Nov, PL) | none needed |
| 12 | Never takes focus; two exceptions | Yes | Only two `NSApp.activate()` calls: `PhewApp.swift:235`, `MenuPanels.swift:246`, both for the folder window and both give focus back. Other app is brought front by `Hand.swift:387, 408` and returned | 7.4: 15 Nov PH (named) |
| 13 | No per-answer display of captured context | Yes by reading | No such view in `Phew/Shell` | none needed |
| 14 | Captures in memory only; never on disk or in a log | Yes by reading; not provable by reading | `WorkingMemory.swift`; `ScreenWatch` writes no frame; debug dump only with the test flag | 7.4: three live tests sent real content to the API (Notes window, browser page, text under the mouse), named; the third was a fault of the product and was fixed (`WindowReader.swift`) |
| 15 | Never read or write secure fields; secrets filter before any network call | Yes | `SecretsFilter.swift`, `SecretsFilterTests`; `Senses.swift:19,41` filter before the packet leaves | 7.4: 14 Nov (a plain-text password slipped through and was fixed) |
| 16 | Speech to text on the device | Yes by code comment and log | `Listener.swift` lines 62, 105; log 15 Nov: no network connection in 5 minutes of sampling | none needed |
| 17 | API key only in the Keychain | Yes | `KeyStore.swift`, `SetupPanel.swift:54`; `git grep sk-ant` finds only made-up test values | none needed |
| 18 | Map only on the Mac, whole Map encrypted, sensitive facts a second lock | Yes | `Database.swift` (SQLCipher), `MapEncryptionTests`; the only network code is `ClaudeProvider.swift` | none needed |
| 19 | Shell and Senses reach the Brain only through `Brain` | Yes by reading | `Brain.swift`; the Shell builds `ClaudeBrain` once, in `PhewApp.swift:140-142` | none needed |
| 20 | One provider interface; model names from the docs | Yes | `ModelProvider.swift` (one table of two models); `ClaudeProvider.swift` | none needed |
| 21 | Small model for Conductor, Observer, Librarian; main for Guide, Follower, Runner | Bent (Observer) | `Conductor.swift:65`, `Observer.swift:27` use `.small`; the Observer runs only above 4,000 characters of screen text | 7.4: 15 Nov PS ("Observer is skipped in practice", named, not a privacy rule) |
| 22 | Map writes only the classes and links of `docs/05-map.md` | Yes | `MapWrite.swift`, `LibrarianTests` | 7.4: 14 Nov (a sixth table, `counter`, named) |
| 23 | Log cost and latency; `calls.log` and `actions.log` hold numbers only; no log holds words | Yes by reading | `CallLog.swift`, `ActionLog.swift`; `shellLog` is compiled only in debug builds (`PhewApp.swift:394`) and every call found logs counts and fixed words | none needed |
| 24 | **"Nothing from the Later section is built during the MVP"** | **No longer matches.** The notch (L1 Character, "notch home") has its listening shape built (P6.4, `NotchListening.swift`, `NotchTests`) | `roadmap.html` L1; log 16 Nov | 7.4: 16 Nov P6 "Rule bent, named: the notch was in Later (L1)" |

Three lines in `CLAUDE.md` no longer match the build: the consent screen (rule 2), the one confirm for an agent (rule 10), and "nothing from Later" (rule 24). (`CLAUDE.md` line 21 already allows "the listening shape at the notch"; only the Later rule is out of date on the notch.)

## 5. Roadmap ticks

Looked at: every task line in `roadmap.html` (131 MVP tasks, all ticked; 18 Later tasks, none ticked), the notes in the lines, and the log (7.4). A: the checker ran it and the log or note says so. B: the lead ticked it on a builder's run, an earlier hand test of yours, or the lead's own run. C: ticked on your word with no run.

| Phase | Tasks | A checker's run | B lead on a run | C your word, no run |
|---|---|---|---|---|
| P0 Setup | 5 | 0 | 5 | 0 |
| P1 Shell | 6 | 0 | 6 | 0 |
| P2 Senses | 5 | 0 | 5 | 0 |
| P3 Brain | 9 | 0 | 9 | 0 |
| P4 Pointer | 7 | 0 | 7 | 0 |
| PR Research | 6 | 6 | 0 | 0 |
| PV Your review | 4 | 4 | 0 | 0 |
| P5 Map | 17 | 15 | 0 | 2 |
| PD Direction | 7 | 6 | 1 | 0 |
| PS Conversation and speed | 16 | 5 | 3 | 8 |
| PH Hand and look | 17 | 4 | 13 | 0 |
| PA Agents | 6 | 0 | 6 | 0 |
| PL Live checks | 9 | 0 | 8 | 1 |
| PB Second brain | 4 | 4 | 0 | 0 |
| P6 Voice | 4 | 0 | 1 | 3 |
| PM MVP test | 4 | 0 | 1 | 3 |
| PG GitHub | 5 | 0 | 5 | 0 |
| **Total** | **131** | **44** | **70** | **17** |

Notes on the sorting:
- P0 to P4: the log (11 to 13 November) shows builder runs and your hand tests (P1.3, P1.4, P4) but does not name who ticked. I sorted them B.
- B in PH, PA and PL: the lead ticked, the checker being stopped by your word (log 15 Nov). Several lines carry a note that the real run was smaller than the "done when": PH.7 (not the Excel job), PH.11 (a made-up canvas), PX.5 (no button pressed), PA.4 (two halves, not one run). I kept these in B.
- PG: the checks were real commands (`gh`, the scan). I confirmed PG.3, PG.4 and PG.5 again in section 2. They stay B because the checker did not tick them then.
- PD.6 was ticked by the lead on the checker's stated condition (log 15 Nov).

**The 17 ticked on your word, without a run** (their lines say so):
- P5.16: a conversation continues in the card. Ticked on your word, with PS.
- P5.17: a speed target with the Map on. Ticked on your word, with PS.
- PS.1: one look per colour change, none on scroll. Hand test, your word.
- PS.2: a click on empty space sends no call. Your word.
- PS.3: the next click step shows in under 0.5 s. Your word.
- PS.4: under 0.5 cents per look. Your word (the build measured 0.41).
- PS.6: the screen watch starts and stops as designed. Your word.
- PS.8: no Pause entry. Your word.
- PS.9: "Never read this app" list. Your word.
- PS.11: the conversation card. Your word.
- PL.8: what worked and what not in Dia, Figma, Fusion. Not tried; the line says so.
- P6.1: words appear offline 9 times in 10. Only the Mac's own voices were used; no microphone, no real voice.
- P6.2: works in 3 apps. Only automatic tests.
- P6.3: the third number is at least 36 of 40. The bar was not met: 30 of 40.
- PM.1: 8 of 10 useful questions on real work. Not run.
- PM.2: a later question uses the first. Not run.
- PM.3: 4 of 5 real jobs and 2 of 3 real reports. Not run.

These ticks mean "built", not "proven". Two of them (P6.3, PM.1) state a result that is false or not measured.

## 6. Open points, in one place

**Acting**
- Acting in Dia, Figma and Fusion was never tried (roadmap L18, PL.8; `07-decisions.md` 7.6).
- Changing, sending and deleting are not built (L18; `00-now.md`).
- Returning to the exact window, not only the app; reading an app's menus before acting (L18).
- Two displays, and a wider trick test on real apps and real web pages (L18).
- No confirm exists for what cannot be undone (rule 10 above; L18).
- The practice-window tests can fail when you use the Mac; they are off unless asked for (PH.9, log 15 Nov).

**Agents**
- The search and page limits were never reached in a live run (L18; 7.6).
- Search words are chosen by the model and run at Anthropic; code cannot check them before they go (log 15 Nov, PA).
- Making an Excel workbook may bring Excel to the front (PL.7; fixed or written down, not seen on real work).

**Voice**
- Names are misheard: 4 of 12 made-up names; the pipeline 30 of 40 against a bar of 36 (P6.3; 7.6).
- No real voice and no real microphone were ever measured (P6.1; 7.6).
- Another on-device engine was never compared: permission refused (log 16 Nov). "Remind me to call" is taken as "remember" (log 15 Nov, P6).
- Not seen with a full-screen app or a second display (P6.4).

**Memory and import**
- Importing Claude's export was never run on your real export; the cost (2 to 6 cents, 40 to 90 seconds) is an estimate (log 15 Nov, PB.4).
- ChatGPT and Gemini exports are not read (`05-map.md` 5.10).
- A zip that lies about its sizes is caught only after unpacking (log 15 Nov, PB).
- Two projects whose Claude Code folder names collide share memory files (log 15 Nov, PB.4).
- Two made-up facts ("Phew test 5104", "Phew test 5105") may still be in your real Map (log 15 Nov, PH).
- The folder window and typing in the paste box were not seen on a real screen (log 15 Nov, PB).
- Touch ID on sensitive facts is later (L15). Search by meaning is later (7.1).

**Look**
- The real blurred material, Increase Contrast and Reduce Motion were not seen on screen (log 15 Nov, PX.3).
- The "To undo" line and the "can't be undone" tag are only a slot (log 15 Nov, PX.4).
- The card's "acting in" label does not change after a switch of app (log 15 Nov, PH.7).
- The Figma drawing uses approximations (log 15 Nov, PX.2).

**Privacy and safety**
- Live tests sent real content to the model three times (log 15 Nov; 7.6). The product leak under the mouse was fixed; a fourth case could still exist in an app never tested.
- A page or document can mislead him, and with no confirm a wrong send or delete happens before you can stop it. You accepted this risk (7.1, 15 Nov).
- Three wishes that touch privacy rules wait: follow-up reuse of a screen, whole threads kept per project, "capture by showing" (decision 34).
- The history carries your Gmail address, and two more Mac addresses, as author (section 2).
- Acting can be turned off only from the menu; there is no setting that asks the first time (7.1, 15 Nov).

**Distribution**
- The disk image is signed with a development certificate and not notarised, so other Macs show a warning (README; L8).
- Tests that open a window do not run on GitHub (PG.4).
- Nobody but you has used it. Every claim of demand is desk research (7.6; `12-validation.md`).

**Business**
- Decision 26 (which business target first), 27 (order of later phases), 40 (which cheap validation tests), 41 (first user group, cost of 10 users, what success means) are still open (7.2).
- Decision 36: recurring updates of the app knowledge (7.2).
- `docs/14-company.md` 14.6 lists what an investor reviews; none of it is tested (L17).
- Cost per question about 1.3 cents against the target of 1.5 (04-architecture); the cost research is L16.

## 7. Verdict

- The project is in order as a private MVP: the code, the tests, the release and the GitHub build agree with each other, and the privacy and safety rules hold in the code I read.
- It is not proven: 17 ticks are on your word with no run, 70 on the lead's, and two of them (P6.3, PM.1) state a result that was not reached or not measured.
- Three things first: (1) use it on real work for two weeks and write down each failure, which settles PM.1 to PM.3 and the weak points in acting and voice; (2) 30 of the 38 stale lines were corrected on 16 November, after this control (section 3); correct the 8 left where they are not records, and the three `CLAUDE.md` lines that no longer match, so the next session does not build on old text; (3) before the repository goes public or anyone else installs it, rewrite the history's author address and notarise the app.
