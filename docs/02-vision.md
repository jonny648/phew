# 2. Vision, mission, values

Rewritten on 15 November 2026 for the direction you set that day. Approved by you on 15 November 2026, with the plan of that day.

The direction, in your words of 15 November (`07-decisions.md` 7.1, last row): Phew is an AI collaboration companion for people who create projects. He works with you and does the second-level jobs you delegate, acting on the Mac. Then he educates. He keeps memory and is your second brain. He is not focused on teaching software. Business software training is a separate product under the same brand, later (`08-b2b-targets.md`).

## 2.1 Vision

People who create projects on a Mac have a companion that works beside them, so the project moves forward and they stay in charge of it.

## 2.2 Mission

Phew works with people who create projects on a Mac: he does the second-level jobs they hand him, explains and points when they are stuck, and remembers the project, so their attention stays on the work that needs them.

"Second-level jobs" means the smaller jobs around your main work, the ones you would hand to an assistant sitting next to you. Which jobs he may do is set in the acting design (`07-decisions.md` 7.2, number 39). It is not written yet.

## 2.3 Who Phew is

- His mark is the top of an eggshell, just lifted, drawn in one heavy line (`22-brand.md`). No face, no character.
- Shy. He lives in the menu bar and comes out only when called.
- Gentle and smooth. He does not talk aloud. He listens well.
- He understands what you are doing and works on it with you.
- He shows first. Then, when you say so, he does it. You are there while he works.
- Tidy. Everything about him is in order: how he appears, how he moves, what he keeps.
- Called Phew!. When voice input is built (P6), he answers to phew, few, phiu, pheoo.
- Mac only for now. He may decide to come out to other devices later.

Changed here: the old text said he "shows instead of telling" and lived "in the notch or the menu bar". He now also acts when asked, and the only notch surface today is the listening shape, shown while you hold the key to talk.

## 2.4 Values as rules

Five values. Each is true of what is built, or of what you decided on 15 November.

| Value | Rule for Phew | Status today |
|---|---|---|
| Called, not watching | He reads the screen only when you call him. During a guide he may watch until the guide ends. What he sees stays in memory and is dropped after | Built |
| Works with you, you decide | You choose what he does, by what you ask. With you in the app, he works in front of you. A task you hand over, he does alone in the background and reports back | Decided 15 November. Built in phases PH and PA, little tried on real work |
| Does when asked, shows when asked | Asked to do, he does the whole job by himself. Asked how, he explains or points. When unsure, he shows | Explaining, pointing and acting are built. Acting is little tried on real work |
| Memory is yours | The Map lives on your Mac, encrypted. You can ask what he remembers, correct it, forget it, and export it | Built |
| Stays out of the way | He never takes focus from your app. He never appears unasked. A finished result waits in the menu bar | Built |

Removed because they are false today:

- "Everything he knows is visible and editable in the Map on the dashboard." There is no dashboard. Today you ask him what he remembers, and you can export the Map to one file.
- "Lives in the notch." He lives in the menu bar. At the notch there is only the listening shape while you hold the key to talk.
- "No setup beyond permissions." The MVP needs a Claude API key, pasted once and kept in the Keychain.
- "Consumer value-dense" and "Frontier, where needed". These were aims, not rules anyone could check.

## 2.5 Non-intrusive, defined

1. **He does not interrupt.** He never shows up by himself. A result waits until you look.
2. **He does not ask for many choices.** One way in, sensible defaults.
3. **He does not intrude on privacy.** He looks only when called. Captures are never saved. One honest sentence: memory stays on your Mac, thinking happens in the cloud. When you call him, what he reads on screen is sent to the model to get the answer.

## 2.6 Feature order

Four things you see, in this order. Everything else serves them.

| # | What | Status today |
|---|---|---|
| 1 | **Work together and act.** You hand him a second-level job. He does it on the Mac, in the app you are in, while you are there | Built in phase PH, little tried on real work. Design approved 15 November |
| 2 | **Explain and guide.** He explains what is on screen and guides you step by step by pointing | Exists |
| 3 | **Memory and second brain.** He remembers your projects in the Map and recalls them when needed | Most of it exists: the Map, recall, correct, forget, export. Importing memory from other tools (PB) is built |
| 4 | **Research.** You give him a task, he researches it and reports back | Built (PA) |

Underneath, never the user's job: context understanding, the conversation card and speed (PS), voice input (P6).

Later, not in the MVP: lecture listening, connections to other tools, the dashboard, business software training.

`CLAUDE.md` now carries this order: its rule "Four things you see" replaced "two visible features".

## 2.7 What Phew is not

- Not a chat app you keep open. A conversation starts from what is on your screen and ends when you close it.
- Not an agent you hand work to and leave. He works while you are there, on what you chose.
- Not a talking assistant. Voice is for you to speak to him. He never speaks aloud.
- Not a tool you have to manage. No projects to set up, no prompts to write.
