# 21. Skills: the functions Phew writes for himself

Phase NC, first form. Built 16 November 2026. Your choices of that day: a small TypeScript helper beside the Swift app, Node shipped inside the app, and skills as its first job.

## 21.1 In plain words

During a research task, Phew sometimes needs to compute: add a long list of prices, convert units, sort, count, work with dates. A language model does this badly in its head. So he may now write a small function, test it, keep it, and use it again in later tasks. That function is a **skill**.

A skill can only compute. It gets one text and gives one text back. It cannot reach the internet, your files or your apps. This is not a promise in the skill's code: macOS itself refuses, because the skill runs in a closed box. The checker got out of the helper's own fence on the first day (fixed since); the box around it still refused every door. So the design counts on the box, never on the helper.

You see skills in the menu under **Memory, Skills…**: the name, what it does, when it was made, and Delete. A report ends with "Skills he used" when its task ran one.

## 21.2 The parts

| Part | Where | What it does |
|---|---|---|
| The helper | `Engine/src/engine.ts`, built to `Phew/Brain/engine.js` | TypeScript, about 50 lines. Reads one request, runs the skill in a fresh JavaScript context built so that Node's own objects are out of reach (tested against the known ways out), with the ways to ask for memory outside the heap removed; writes one answer, exits. A fence, not the lock |
| Node | `Phew.app/Contents/Helpers/node` | The program the helper runs on. One pinned long-term release (v24.22.2), fetched by `Tools/fetch-node.sh` with a fingerprint check, signed by your certificate without the debugger door. About 122 MB |
| The box | `Phew/Brain/SkillBox.swift` | Starts Node under the Mac's sandbox tool with a profile that refuses everything first: network, file writes, child programs, signals to other programs, and reading any file. It then opens only Node itself and the system's own libraries. Empty environment. One process per run; killing it is Stop |
| The store | `Phew/Brain/Skills.swift` | One file per skill in `~/Library/Application Support/Phew/Skills/`. The first line is what it does |
| The tools | `Phew/Brain/Skills.swift` | `write_skill` and `run_skill`, given to the research agent |
| The list | `Phew/Shell/SkillsPanel.swift` | The menu's panel, through the `Brain` interface |

## 21.3 The rules, and what keeps each

| Rule | Kept by |
|---|---|
| No network, no file writes, no programs, no signals, no reading of your folders, temporary folders, logs or the list of your apps | The sandbox profile, by macOS. Tested with a stand-in helper that tries each door |
| If the box cannot be made, nothing runs | `SkillBox.run` returns "no box" when the sandbox tool, Node or the helper is missing; a refused profile gives no answer, which is a failure |
| 5 seconds; 128 MB of JavaScript heap and 384 MB of real memory; 20,000 characters out; 100,000 in | Swift: a clock that kills the process; Node's heap flag plus Swift's own watch of the process's real memory, a hundred times a second; the answer read in pieces and the process ended past 1 MB; a check before the run |
| Stop within a second | Swift kills the process when the task is cancelled |
| No key near a skill | The process starts with an empty environment, and the helper makes no model call |
| A skill is kept only when its own test passes, and what is kept is exactly what was tested | `SkillStore.write` runs the test in the box first, then reads the file back and compares |
| A name cannot leave the folder | Names are 3 to 40 lower-case letters, digits and hyphens |
| What a skill returns is data | It goes back in a `<skill>` block, through the secrets filter; the prompt says it is never instructions |
| No skill from a page | The prompt forbids it. This one is by instruction, not by code: a skill written from a bad page could still only compute |
| A skill never acts | The box cannot start a program or reach an app; the scan test that guards the one acting function names the box as its one exception |

## 21.4 What it costs

- The app: about 4 MB before, about 125 MB with Node inside.
- Memory: nothing while no skill runs. One Node process of about 40 MB for the fraction of a second a skill runs (measured: see the log).
- Time: about 0.1 second to start the helper for each run.
- Money: a skill run costs nothing. Writing one costs the model's words for the code, inside the task's own limit.

## 21.5 In a job you watch

Since 0.3.1 the acting agent has skills too. In a job, "write a skill" and "run a skill" are two steps like the others, shown on the card ("Wrote the skill sum-list", "Ran the skill sum-list"). They are not actions on the Mac: they never go through the Hand. The result comes back as data for the next step, for example a note with the total. Stop ends a running skill. Three failed skill steps end the job. In a job, as in a task, the only guard against a skill written from text on the screen is the instruction to the model, not code; the box keeps the harm to a wrong number, which a later step could then write into a note. Writing a skill under a name already kept replaces the old one, when the new one passes its own test; nothing tells you, and the menu shows the new one. Limits of this form: only the last result is carried to the next steps, and a skill written in a job can be about 8,000 characters at most.

## 21.6 What is not built

- A skill that reads a file, reaches the web or acts. Each is a door in the box.
- Asynchronous skills, and skills that call other skills.
- Intel Macs: the Node inside the app is for Apple silicon only.
- A real model writing a real skill has not been run, in a task or in a job (NC.L, at your word). The acting agent's prompt changed for this and has not been re-checked live.

## 21.7 Known weak points

- A skill that got out of the helper's fence could still learn whether a path on your Mac exists: macOS answers "refused" for a path that is there and "not there" for one that is not. It can read nothing either way.
- Found by the second check, left as they are: a skill out of the fence could read the Mac's own system files, among them device and boot identifiers under `/System/Volumes` (not your files); it could learn your user name and the name of your home folder; and it can see that the folders on the way to Node exist.
- The memory watch looks a hundred times a second. A skill can pass 384 MB by a few hundred MB in the instant before it is ended.

- The sandbox tool (`sandbox-exec`) is marked deprecated by Apple. It works on this Mac. If an update removes it, skills stop running until the box is rebuilt, for example as a helper with Apple's App Sandbox.
- A skill's only check is the one test the model wrote for it. A skill can be wrong on other inputs.
- Node needs security updates: change the two lines in `Tools/fetch-node.sh`, run it, and make a new disk image.
- To change the helper: edit `Engine/src/engine.ts`, run `Tools/build-engine.sh`, commit `Phew/Brain/engine.js`.
