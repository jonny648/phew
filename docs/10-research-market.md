# 10. Research: Market and competitors

Split on 14 November 2026 from what was one research file, one file per part, with section numbers kept. All parts are listed in `README.md`.

Done on 13 November 2026 by research agents on the web. Each fact carries a source number; the sources are listed at the end of the part. "Not confirmed" means the page could not be opened or the vendor does not say.

This file is the record of what the research found and advised. Where you decided differently, a line marked "What was decided" says so. Those lines were added on 14 November 2026. Where this file and the design documents differ, the design documents count.

## 10.1 Market and competitors

The market map is drawn in Figma: https://www.figma.com/design/XDdAxJoezQI2GXmxQBOn0m

**Headline: pointing at the screen is no longer an empty space.** At least six consumer products and one Microsoft feature do it. What nobody on the Mac offers is the combination: a guide that points, remembers your projects, keeps that memory on your Mac, and looks only when called.

### Competitors

Prices in US dollars per month. "nc" means not confirmed on a page that was opened. Sees: when it looks at the screen. Alone: what it does without you.

| Product | Group | For | Price | Sees | Memory | Alone | Points | Data | Src |
|---|---|---|---|---|---|---|---|---|---|
| HeyClicky (was Clicky) | Companion | Individuals | Free, 20, 100 | Asked | Short summaries | Acts | Yes | Cloud | M8 |
| Peek | Companion | Individuals | 10 (launch price, 15 shown beside it), 25 | Asked | Answer history | Acts | Yes, waits for your click | Voice on Mac, picture to cloud | M11 |
| Guidy | Companion | Individuals | Free, 9.99 | Asked | None | No | Yes | Cloud | M12 |
| DesktopBuddy (Windows) | Companion | Individuals | Free, 29, 49 | Asked | Long-term, claimed | Acts | Yes | Unclear | M13 |
| Clippi | Companion | Individuals, site owners | Free, 4.99, 9.99 | Asked | Chat history | Acts on websites | Yes | Cloud | M14 |
| PathTutorial (Windows) | Companion | Individuals | Free | Asked | None | No | Yes | Not stated | M15 |
| Copilot Vision, Highlights | System | Individuals | With Microsoft 365, nc | Asked | None | No | Yes | Cloud | M5, M6 |
| Cluely | Companion | Individuals, sales | Free, 19.99, 149.99 | Always in meetings | Past meetings | No | No | Cloud | M16 |
| Highlight AI | Companion, memory | Individuals to teams | Free, 35, 200 | nc | Projects | Scheduled skills | No | Cloud | M17, M18 |
| Littlebird | Companion, memory | Individuals, teams | Free, 17, 42.50, 100 | Always | Projects | Routines | No | Cloud | M19 |
| ChatGPT desktop | Assistant | Everyone | Free, 20 nc | Asked, nc | Chat | Acts | No | Cloud | M1, M2 |
| Claude desktop, Cowork | Assistant, agent | Everyone | Free, 20, 100, 200 | Asked | Projects | Acts | No | Cloud | M3 |
| Gemini Mac app | Assistant | Individuals | Free | Asked | Chat | Acts, with approval | No | Cloud | M4 |
| Perplexity Comet | Agent, browser | Individuals | Free, nc | In the browser | Not stated | Acts in the browser | No | Cloud | M7 |
| Manus | Agent | Individuals, teams | Credits, nc | Asked | nc | Acts | No | Cloud | M29 |
| Dia | Agent, browser | Individuals, teams | Free | In the browser | Chat | Research | No | Cloud | M30 |
| Simular | Agent | Individuals, business | Not listed | Asked | nc | Acts | No | Mac and cloud | M31 |
| Apple Siri AI | System | Individuals | Free | Asked | Personal context | Acts in apps | No | Device and Apple cloud | M32 |
| Microsoft Recall | System, memory | Individuals | In Windows | Always | Timeline | No | No | Device | M23 |
| Screenpipe | Memory | Individuals, developers | Free, 21, 42 | Always | Projects | Scheduled | No | Device | M22 |
| MemoryPlugin | Memory | Individuals | 89 a year | No | Shared across AI chats | No | No | Cloud | M24 |
| Supermemory | Memory | Developers | Free, 19, 100, 399 | No | Projects | No | No | Cloud | M25 |
| Mem | Memory, notes | Individuals | Free, 9, 29 | No | Projects | Routines | No | Cloud | M26 |
| Granola | Memory, meetings | Teams | Free, 14, 35 | Audio only | Meetings | No | No | Cloud | M27 |
| Raycast AI | Work tool | Individuals, teams | 10, 20, 50 | Asked | Chat | No | No | Cloud | M33 |
| Notion AI | Work tool | Teams | 21, nc | No | Workspace | Custom agents | No | Cloud | M34 |
| WalkMe | Guidance | Enterprise | Quote | Inside set-up apps | None | Fills forms | Yes, written by a company | Cloud | M35 |
| Pendo | Guidance | Product teams | Free, quote | Own app only | None | No | Yes, written by a company | Cloud | M36 |
| Tango | Guidance | Teams | Free, 20 to 30 | No | None | No | Yes, recorded | Cloud | M37 |
| Scribe | Guidance | Teams | Free, 17, 35 | No | None | No | Partly, recorded | Cloud | M38 |

Gone or absorbed: Rewind and Limitless, bought by Meta and switched off in December 2025 (M21). Sky, bought by OpenAI before it shipped (nc).

Public traction, where a figure exists: ChatGPT about 900 million weekly users (February 2026, M2). HeyClicky "25,000+ users" (its site, M8); the open-source Clicky has 8,000 stars and can be copied freely (M10). Highlight AI raised $40M, 500,000 users (March 2026, M18). Littlebird raised $11M (March 2026, M20). Granola raised $125M at a $1.5B value (March 2026, M28).

### The gap

**Already filled**
- A pointing guide for individuals: HeyClicky, Peek, Guidy, Clippi, DesktopBuddy, PathTutorial, and Microsoft inside Windows.
- A guide that follows you: Peek "waits for your click, looks again, then shows the next, up to 15 steps". Phew's P4.7 is not unique.
- Agents that work alone: every large lab, plus HeyClicky and Peek.
- Voice: most of them.

**Still open**
- **Pointing with project memory.** The guides remember little or nothing. The memory tools do not point. On the Mac, nobody has both.
- **Memory on the Mac, looking only when called.** Local memory exists only in tools that record all the time (Screenpipe, Recall). Tools that look only when called keep almost nothing.
- **Silent.** Most pointing competitors answer aloud: Peek, Clippi, DesktopBuddy and PathTutorial say so on their sites, and HeyClicky is built around talking to it (M8, M11, M13, M14, M15). Guidy's site mentions no voice (M12), so silence alone does not set Phew apart.
- **Europe.** Apple's new Siri is not available in the EU for now (M32).

**Hard truths**
1. "Local" is a weak claim while pictures go to a cloud model. The honest wording is: memory on your Mac, thinking in the cloud.
2. People pay little for pointing: a first paid plan costs $5 to $29 a month, with free options. Top plans reach $100.
3. Paying for personal memory is unproven. Rewind was sold and shut; Highlight and Littlebird are moving to teams and meetings. This is a reading of their moves, not a published fact.
4. Apple, Microsoft, Google and OpenAI are each one feature away. Expect the gap to narrow within 6 to 12 months. This is a judgement, not a published fact.
5. Going general puts Phew directly against HeyClicky and Peek, with no advantage until the memory works.

**Opportunity Phew builds on:** the one companion that knows your projects. He points like the others, but he already knows what you are working on, keeps that knowledge on your Mac, and never watches when not called. The defence is the combination, not any single feature.

### Market size

| Market | Figure | Source |
|---|---|---|
| AI agents | $7.84B in 2025 to $52.62B in 2030 | MarketsandMarkets, April 2025 (M39) |
| AI agents | $50.31B by 2030 | Grand View Research, May 2025 (M40) |
| Desktop AI companions | No credible figure exists | |

These count mostly business software. None measures consumer desktop companions.

### Sources

- M1 https://chatgpt.com/pricing
- M2 https://www.eweek.com/news/chatgpt-hits-900m-weekly-users/
- M3 https://claude.com/pricing
- M4 https://gemini.google/mac/
- M5 https://support.microsoft.com/en-us/Microsoft-Copilot/using-copilot-vision-with-microsoft-copilot
- M6 https://blogs.windows.com/windowsexperience/2025/06/12/copilot-vision-on-windows-with-highlights-now-available-in-us/
- M7 https://www.perplexity.ai/comet
- M8 https://www.heyclicky.com/
- M10 https://github.com/farzaa/clicky
- M11 https://usepeek.app/
- M12 https://guidy.ai/
- M13 https://desktopbuddy.ai/
- M14 https://clippi.us/
- M15 https://pathtutorial.com/blog/chatgpt-cant-click-buttons-on-your-pc
- M16 https://cluely.com/pricing
- M17 https://highlightai.com/pricing
- M18 https://siliconangle.com/2026/03/24/ai-productivity-startup-highlight-ai-raises-40m-appoints-new-ceo/
- M19 https://littlebird.ai/pricing
- M20 https://builtin.com/articles/littlebird-raises-11m-seed-20260325
- M21 https://9to5mac.com/2025/12/05/rewind-limitless-meta-acquisition/
- M22 https://screenpipe.com/pricing
- M23 https://support.microsoft.com/en-us/windows/retrace-your-steps-with-recall-aa03f8a0-a78b-4b3e-b0a1-2eb8ac48701c
- M24 https://www.memoryplugin.com/
- M25 https://supermemory.ai/pricing
- M26 https://get.mem.ai/pricing
- M27 https://www.granola.ai/pricing
- M28 https://thenextweb.com/news/granola-series-c-meeting-ai-enterprise-context
- M29 https://techcrunch.com/2026/06/13/meta-reportedly-moves-to-unwind-2b-manus-deal-after-beijings-demand/
- M30 https://www.diabrowser.com/
- M31 https://www.simular.ai/
- M32 https://9to5mac.com/2026/06/08/new-siri-whats-new/
- M33 https://www.raycast.com/pricing
- M34 https://www.notion.com/pricing
- M35 https://www.walkme.com/
- M36 https://www.pendo.io/pricing/
- M37 https://www.tango.ai/pricing
- M38 https://scribe.com/pricing
- M39 https://prnewswire.co.uk/news-releases/ai-agents-market-worth-52-62-billion-by-2030---exclusive-report-by-marketsandmarkets-302435498.html
- M40 https://www.prnewswire.co.uk/news-releases/ai-agents-market-size-to-hit-50-31-billion-by-2030-at-cagr-45-8---grand-view-research-inc-302447061.html

Limits: pages were read through a tool that summarises them, not by eye, so check a price on the live page before quoting it. The scores used to place products on the map are a judgement, not data.
