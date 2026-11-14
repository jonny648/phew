# 1. Foundation

## 1.1 Problem

People who work on a Mac use AI every day and now spend real effort managing it: choosing the tool, explaining the context again, moving text and screenshots, switching apps, deciding between too many options behind a chat box.

One sentence: **the AI lives somewhere else and does not know what I am doing.**

Numbers from the research:

- 95% of UK undergraduates use AI. 61% use it to have concepts explained (HEPI 2026, n = 1,054).
- 85% of US college students used AI for coursework in a year.
- About 1,200 app toggles a day, about 9% of work time lost reorienting (HBR 2022, n = 137).
- Productivity rises with up to three AI tools and falls at four or more (BCG 2026, n = 1,488).

The first two figures are about students, the first users Phew was planned for. Status: desk research only. Validation with users was skipped by your decision on 10 November 2026.

## 1.2 User

People who work on a Mac and use AI daily: designers, students, founders, developers, writers. Widened from university students on 13 November 2026. First user: you.

Job to be done: help me understand and move forward on what is in front of me, without leaving it and without explaining my project again.

## 1.3 Market

- Sector: screen-aware desktop AI companions, inside AI assistants and agents.
- Parent market: AI agents, about $7.6B to $7.8B in 2025, about $50B to $53B by 2030. Mostly enterprise. No credible figure for consumer companions.
- Screen reading alone became a free macOS feature on 14 September 2026.
- No credible figure exists for desktop companions. See `10-research.md` 10.1.

## 1.4 Competitors

Researched on 13 November 2026: 32 products, in `10-research.md` 10.1 and in the Figma market map linked there. The closest:

| Product | Overlap | What Phew does differently |
|---|---|---|
| HeyClicky (was Clicky), Peek, Guidy, Clippi | Companions that see the screen and point. Peek also waits for your click | They remember little or nothing, and most of them talk. Phew knows your projects, is silent, and keeps his memory on the Mac |
| Littlebird, Highlight AI, Screenpipe | Memory of your work | They watch all the time and do not point. Phew looks only when called |
| Siri AI, Copilot Vision | On-screen awareness built into the system | No project memory kept for you, no guide that follows you. Siri AI is not in the EU for now |
| ChatGPT, Claude, Gemini desktop | General help with screen context | A chat to manage. Phew removes the chat |
| MemoryPlugin, Supermemory | Shared memory | Memory only, no experience |

## 1.5 Position

The one companion that knows your projects. Pointing at the screen is now common; pointing with memory is not. Phew points like the others, already knows what you are working on, keeps that knowledge on your Mac, and never watches when not called. The honest wording of the privacy claim: memory on your Mac, thinking in the cloud.

The experience is the product. Memory, context, agents and the Map work underneath and are never the user's job.

## 1.6 Risks

- Scope. This is five products in one. Since 13 November 2026 the MVP in `06-sprint.md` carries most of it: explain and guide, memory of your projects, the second brain, a faster guide, a task he researches alone, and speech. There is no deadline, so nothing is skipped. Lecture listening, actions in other apps, connections to other tools and the dashboard wait.
- Apple, Microsoft, Google and OpenAI are each one feature away from pointing. Expect the gap to narrow within 6 to 12 months.
- People pay little for pointing (a first paid plan costs $5 to $29 a month), and paying for personal memory is unproven.
- An agent that reads the web can be tricked by hidden instructions. Rules in `10-research.md` 10.2.
- Trust: screen, microphone and actions in other apps are the three most sensitive permissions on a Mac.
- Model cost per user against what a user pays.
- Students and early founders rarely pay for tools. See 1.7.
- The name: check trademark and domain for Phew before public use.

## 1.7 Who pays

Students and early founders are heavy users and weak payers. As a consumer product this would likely need to be free or open source. The paying versions are business ones, where an organisation buys and an individual uses. See `08-b2b-targets.md`.

For now this does not change the build. Phew is a personal tool and a learning project. Since 13 November 2026 the MVP is designed for anyone who works on a Mac.
