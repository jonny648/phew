# 10. Research for phase PR

Done on 13 November 2026 by research agents on the web, in five parts (10.1 to 10.5). Each fact carries a source number; the sources are listed at the end of each part. "Not confirmed" means the page could not be opened or the vendor does not say.

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

## 10.2 How similar tools work

### How they see the screen

| Tool | How | When |
|---|---|---|
| Raycast AI | Accessibility text, selected text, screenshot of the focused window | Only when you ask (W14) |
| Clicky (open source) | Screenshot on a hotkey, sent to Claude. Points through tags in the reply | Only on the hotkey (W11) |
| ChatGPT desktop, Work with Apps | Accessibility, for a short list of apps | When you pick an app. Not confirmed (W1) |
| Claude desktop, Cowork, computer use | Screenshots, in a loop | Every step (W2, W3, W4) |
| Apple Intelligence | No pixels. Only what each app chooses to expose | When you refer to it (W8) |
| Littlebird | Accessibility text of the active window, stored in the cloud | Every few seconds (W12) |
| Screenpipe | Screenshot and Accessibility, stored on the Mac | On system events, about every 5 s when idle (W13) |
| Highlight AI, Cluely | Method not stated by the vendor | Continuous, or per session (W9, W10) |

Three patterns: capture when called (Raycast, Clicky, and Phew today), continuous memory (Littlebird, Screenpipe, Highlight), and a screenshot loop to act (all computer-use agents).

### How they work alone

| Pattern | Needs | Cost and speed | Failures |
|---|---|---|---|
| Web research agent | Only the Claude API. Search and fetch run at Anthropic | $10 per 1,000 searches plus tokens. Fetch is free plus tokens, about 2,500 tokens a page (W15, W16) | None published |
| Scheduled tasks | Anthropic's cloud (Managed Agents) | Tokens plus $0.08 per session-hour (W19, W21) | Missed runs are not repeated |
| Agents that click and type | Accessibility and Screen Recording, screenshot loop | 1,000 to 1,800 tokens per screenshot. "Slower than connectors" (W2, W4) | "Complex tasks sometimes need a second try" (W2) |
| Agents limited to a folder | A folder you choose | Tokens only | None published (W20) |
| Tool connections (MCP) from the API | A public server on the internet. Local ones cannot be reached (W23) | Tokens only | None published |

Anthropic's own order of preference: a connection first, then files, then the browser, and control of the screen last, because it is "the broadest and slowest" (W3).

### Consent and safety, as others do it

- Approval per app, per session, with a plain warning of what the grant means (Claude, W3).
- A visible "working" notice and one key that always stops (Claude, W3).
- Confirmation before anything that cannot be undone; purchases and account changes blocked (W20, W24).
- Password fields ignored, password managers excluded, a pause switch (Littlebird, W12).

**The main risk for an agent that reads web pages:** a page can contain hidden instructions that try to make the agent send out what it knows (your screen text, your memory). Every vendor says its defences are not perfect: "No browser agent is immune to prompt injection" (Anthropic, W27); "Treat screen content as untrusted" (OpenAI, W25).

Rules to build in from the first day:
1. Screen text, memory and file contents go to the model as data, never as instructions (W26).
2. A limit on searches, fetches and tokens per task (W15, W16).
3. The agent may not open a web address that came from the screen, the memory or a file. The fetch tool does not do this by itself: by default it opens any address found in the user's message or in a tool result (W16).
4. The secrets filter runs before every call, as today.
5. The research agent has no tool that writes or changes anything. This follows the advice to give an agent the least power it needs (W26).

**What was decided.** On 13 November you approved the rules for agents; they are hard rules in `CLAUDE.md`. How each one is kept is written in `03-experience.md` 3.6 and `04-architecture.md` 4.4. Where this part and those two differ, those two count. Three points go further than the research:

- Rule 2: the limits are on searches, pages and cost, not tokens. First proposals: 5 searches, 8 pages, 50 cents (see Open in `07-decisions.md`, limits per task). Searches and pages are capped in the request itself, with `max_uses` on each tool (W15, W16). `max_uses` counts inside one request, so Phew's code lowers it by what the earlier requests of the same task used. Phew's own code adds up the cost after each reply.
- Rule 3 is kept by two guards, not by asking the model. First, Phew's own code removes every web address from the screen text, the Map facts, each Map search result and file text before sending. Second, the fetch tool's `url_sources` setting has `user_input` and `client_tool_results` both set to `{"type": "none"}` (W16). The agent can then open only addresses from its own web searches and from pages it already opened. Anthropic's server refuses the rest. Side effect: an address you type in the task is not opened directly. He finds that page by searching. This is a first proposal (see Open in `07-decisions.md`, a web address you type in the task). Re-read W16 before building.
- Rule 5: the agent has exactly three tools: web search, web fetch and Map search. None writes or changes anything. The report file (level B1 below) is written by Phew's own code when the report is ready, never by the model.

One risk stays that no rule removes: a web page can still try to steer what he searches for next. The limits, and the absence of any tool that changes things, keep the damage small.

### What the Claude API offers, from a Mac with only a key

| Feature | Fits Phew? |
|---|---|
| Web search and web fetch (server tools) | Yes |
| Prompt caching | Yes |
| Computer use tool | Works, but not for version 1 |
| MCP connector | Only public servers |
| Memory tool | Not needed, Phew has the Map |
| Managed Agents and scheduled runs | No. The work and its transcript live on Anthropic's servers, against the memory-only rule |
| Agent SDK | No. Python and TypeScript only, not Swift |
| Batches | No. Too slow for a task you wait on |

Prices on 13 November 2026 (W21): Sonnet 5.5 $2 in, $10 out per million tokens. Haiku 5.5 $0.10 in, $0.50 out.

### Three levels for version 1

Days are the research agent's rough estimate for one builder with AI help. They are not measured.

| Level | Adds | Days | Risk |
|---|---|---|---|
| A. Read and research | One screen read at the start, the Map, web search, a report on the card | 4 to 7 | Low to medium: a web page tricks the agent, or cost runs away |
| B1. New files in one folder | The report saved as a file in a folder you choose. Never overwrites | 2 to 3 more | Low: an unwanted new file |
| B2. Editing files in that folder | Each change shown, approved by you, with a backup | 4 to 6 more | Medium: data loss if the backup logic is wrong |
| C. Acting in apps | Clicks and typing | 15 to 30 or more | High |

Finding: B1 is the only step beyond reading that is both safe and small. C also breaks the rule that Phew never takes focus.

**What was decided.** On 13 November you put levels A and B1 in the MVP, as phase PA. B2 and C come after the MVP.

### Copy, avoid

Copy: capture only when called; structured data before pixels; plain per-session approval; a stop key and a visible "working" mark; one working folder.

Avoid: continuous capture; captured context stored in a cloud; a click-and-type loop in version 1; opening addresses found on the screen; trusting the model alone to resist hidden instructions.

### Sources

- W1 https://help.openai.com/en/articles/10119604-work-with-apps-on-macos (not opened, blocked)
- W2 https://support.claude.com/en/articles/14128542-let-claude-use-your-computer-in-cowork
- W3 https://code.claude.com/docs/en/computer-use
- W4 https://platform.claude.com/docs/en/agents-and-tools/tool-use/computer-use-tool
- W8 https://developer.apple.com/documentation/appintents/apple-intelligence-and-siri-ai.md
- W9 https://highlightai.com/privacy
- W10 https://cluely.com/
- W11 https://github.com/farzaa/clicky
- W12 https://littlebird.ai/blog/what-does-littlebird-actually-see
- W13 https://docs.screenpipe.com/architecture
- W14 https://manual.raycast.com/ai/screen-awareness.md
- W15 https://platform.claude.com/docs/en/agents-and-tools/tool-use/web-search-tool
- W16 https://platform.claude.com/docs/en/agents-and-tools/tool-use/web-fetch-tool
- W19 https://platform.claude.com/docs/en/managed-agents/scheduled-deployments
- W20 https://support.claude.com/en/articles/13364135-use-cowork-safely
- W21 https://platform.claude.com/docs/en/about-claude/pricing
- W23 https://platform.claude.com/docs/en/agents-and-tools/mcp-connector
- W24 https://support.claude.com/en/articles/12902446-claude-for-chrome-permissions-guide
- W25 https://developers.openai.com/api/docs/guides/tools-computer-use
- W26 https://platform.claude.com/docs/en/test-and-evaluate/strengthen-guardrails/mitigate-jailbreaks
- W27 https://www.anthropic.com/research/prompt-injection-defenses

## 10.3 The second brain: memory you already have in other AI tools

### What each tool keeps, and how to get it out

| Tool | What it remembers | How you get it out | A way for another app to read it |
|---|---|---|---|
| Claude (claude.ai) | Memory by topic: role, projects, people, preferences. One memory per project (B1) | Settings, Your Claude, Manage: copy the text. Or ask Claude to write out its memories (B2). Whether a full data export contains memory is not confirmed: the export page lists conversation data, account data and voice recordings, and names neither memory nor a file layout (B3) | None. Claude itself imports from others by paste (B2) |
| Claude Code | `CLAUDE.md` files and a memory folder of small Markdown files, on the Mac (B5) | Nothing to export: plain files on disk | Yes, plain files |
| ChatGPT | Saved memories and a summary of past chats; project memory; custom instructions. Not confirmed, OpenAI's pages were blocked (B7, B8) | Settings, Data controls, Export data. A zip by email, up to 7 days. Not confirmed, the page was blocked; whether saved memories are inside is also not confirmed (B7) | None found |
| Gemini | Saved info, past chats, a memory summary. The summary is not available in the EEA, Switzerland or the UK (B12, B14) | Google Takeout. Memory is not stated as included (B15) | None. Gemini imports from others by paste or zip, not in the EEA (B10) |
| Copilot, Perplexity | Memories and history (B18, B20) | No confirmed memory export | None found |

**The vendors move memory between assistants by prompt and paste, not by file.** Claude's own import asks the old assistant to list every stored memory in one block, and you paste it (B2). Gemini does the same (B10). No export has a documented file format.

Terms: reading a file you exported yourself is not the same act as scraping the service. Anthropic's terms forbid scraping; Google's forbid automated access that goes against the instructions on its pages (B4, B17). For OpenAI this is not confirmed, the page was blocked (B11). This is a reading, not legal advice.

### How others build a memory

| Project | Storage | Weak point for Phew |
|---|---|---|
| MemoryPlugin | Editable entries in a cloud service (B22) | Data leaves the Mac |
| Mem0, Supermemory | A model extracts facts; search by meaning and by words (B23, B24) | A model call on every write |
| Zep, Graphiti | A graph where facts have dates and old ones are marked invalid, not deleted (B25) | Needs a graph server |
| Letta | Small memory blocks always in the prompt (B26) | A server framework |
| Claude Code | Plain Markdown files, an index capped at 200 lines (B5) | Grows without limit unless capped |

### Four ways to store memory on one Mac

| Way | Effort | Quality at Phew's size | Risk |
|---|---|---|---|
| A text file always in the prompt | Lowest | Perfect while small | Grows, goes stale, costs on every call |
| SQLite graph of things and links (the Map as planned) | Medium | Exact for "which project, file, app" | Duplicates, wrong links written by the model |
| Search by meaning (embeddings) | Highest | Small gain at this size | Silent bad matches; the SQLite add-on is not yet stable (B32) |
| SQLite full-text search, built in | Low | Good when words match | Misses synonyms |

Anthropic's guidance: the context is "a finite resource"; load a little up front and fetch the rest when needed (B36). Keep recent turns word for word (B38).

### Risks of importing

- **Old or wrong facts.** A memory list can be incomplete or out of date. Claude's page says memory imports are experimental and may not be kept in full (B2). OpenAI's page was not opened (B8).
- **Secrets and personal data.** A full chat export contains everything you ever typed. The import must pass the secrets filter, and it sends your memory to the Claude API to be sorted.
- **Hidden instructions.** Shown in a real attack on ChatGPT's memory: a document made it store instructions that leaked data in later chats (B40). Imported text must be treated as data only.
- **Size.** Full exports reach gigabytes. A memory list is a few kilobytes.

### Recommendation

**Build for version 1:** the Map as planned, plus full-text search over it, plus one small profile (who you are, your projects, your preferences, about 200 lines at most) loaded on every call, plus the recent turns of the current conversation so follow-up questions work.

**Leave out of version 1:** search by meaning, any graph server, reading export zips.

**Import, smallest form:** a paste box. You ask your assistant to list what it remembers about you and paste the answer. Phew filters secrets, sorts the text into facts, shows them to you to tick, and stores the ticked ones marked "imported" with the date. One path for Claude, ChatGPT and Gemini. The research agent placed this after version 1.

**What was decided.** On 13 November you put the paste box in version 1, as phase PB, together with reading Claude Code's `CLAUDE.md` and memory files on the Mac. Reading export zips stays after the MVP. The design is in `05-map.md` 5.10.

Sources, easiest and most useful first: a pasted memory list; pasted custom instructions; Claude Code's files on the Mac; the ChatGPT zip; the Claude zip; Google Takeout.

### Sources

- B1 https://support.claude.com/en/articles/11817273-using-claude-s-chat-search-and-memory-to-build-on-previous-context
- B2 https://support.claude.com/en/articles/12123587-importing-and-exporting-your-memory-from-claude
- B3 https://support.claude.com/en/articles/9450526-how-can-i-export-my-claude-data
- B4 https://www.anthropic.com/legal/consumer-terms
- B5 https://code.claude.com/docs/en/memory
- B7 https://help.openai.com/en/articles/7260999-how-do-i-export-my-chatgpt-history-and-data (not opened, blocked)
- B8 https://help.openai.com/en/articles/8590148-memory-faq (not opened, blocked)
- B10 https://support.google.com/gemini/answer/16868299
- B11 https://openai.com/policies/row-terms-of-use/ (not opened, blocked)
- B12 https://support.google.com/gemini/answer/15637730
- B14 https://support.google.com/gemini/answer/18617127?hl=en
- B15 https://support.google.com/gemini/answer/16920332?hl=en
- B17 https://policies.google.com/terms
- B18 https://support.microsoft.com/en-us/microsoft-copilot/microsoft-copilot-privacy-controls
- B20 https://www.perplexity.ai/help-center/en/articles/10968016-memory
- B22 https://www.memoryplugin.com/
- B23 https://github.com/supermemoryai/supermemory
- B24 https://github.com/mem0ai/mem0
- B25 https://github.com/getzep/graphiti
- B26 https://docs.letta.com/guides/agents/memory
- B32 https://github.com/asg017/sqlite-vec
- B36 https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
- B38 https://platform.claude.com/docs/en/build-with-claude/compaction
- B40 https://embracethered.com/blog/posts/2024/chatgpt-macos-app-persistent-data-exfiltration/

Limits: no real export file was opened, so every file layout is unconfirmed. Before building a file importer, request one export from each assistant and look inside.

## 10.4 Guide speed and cost

Starting point, measured by Phew: 1 s wait, then 2.1 s per look on average and up to 6.2 s; 4,531 tokens and 0.9 cents per look. "Estimate" below means nobody has measured it.

### Three findings that change the picture

- **The picture is less than half of what is sent.** At today's sizes it is about 1,700 to 1,950 of the 4,531 tokens, roughly 40% (see the table under "Sending less"). The window text and the list of 80 elements are the rest (G5).
- **The small model is 20 times cheaper**: $0.10 against $2 per million tokens (G2). A look on it would cost about 0.045 cents.
- **Speed cannot be bought.** The faster service options do not cover the two models Phew uses (G9, G10).

### Knowing the screen changed, without the model

| Signal | Works where | Limit |
|---|---|---|
| Comparing the window text and elements with the last look | Native apps, panels | Blind to the Figma canvas (G20) |
| Comparing two small versions of the picture | Everywhere | A very small change can be missed. Timing is an estimate: under 5 ms |
| Accessibility notifications | Native apps | Browsers, Electron apps and Figma often send nothing (G18, G19) |
| A live screen stream that reports what was redrawn | Everywhere, the best signal (G14) | It watches the screen all through the guide. The research left this to your decision on the rule "he reads the screen only when called". You approved it on 13 November for the length of a guide: see "What was decided" below |

A look can be skipped when both the text and the small picture are unchanged. Neither alone is enough.

### Sending less

A picture costs (width ÷ 28, rounded up) × (height ÷ 28, rounded up) tokens. On Claude 4.7 and later models, which includes the main model, the limit is 4,784 tokens per picture; a larger picture is shrunk first (G5).

| Picture | Tokens | Cost on the main model |
|---|---|---|
| Whole display, 1512×982 | 1,944 | 0.39 cents |
| Window, 1440×900 | 1,716 | 0.34 cents |
| Cut around the target, 560×420 | 300 | 0.06 cents |

The documentation advises cutting to the region of interest for small targets. The model then answers with positions inside the cut picture, so the position of the cut on the screen must be added back before pointing (G26). Caching the fixed part of the request saves about 0.15 cents per look and almost no time; it needs at least 512 fixed tokens (G7).

### The slow looks

The model's guide says that with structured answers at low effort "the model occasionally keeps thinking until it reaches `max_tokens`", and to treat that as a failure and retry (G12). This may be the cause of the 6.2 s looks. Not confirmed against Phew's logs.

### How it feels

- 0.1 s feels instant, 1 s keeps the flow of thought, beyond that show that something is happening (G22). Phew's 3.1 s per step is past that limit on every step.
- Business guidance tools (WalkMe, Pendo) move to the next step the moment you click the marked element, without asking a server (G23, G24).
- Apple: put the status near the thing it describes, and keep it moving (G25).

### Five changes, best first

Effects are estimates.

| # | Change | Speed | Cost per look | Looks per guide | Risk |
|---|---|---|---|---|---|
| 1 | No look while you drag or scroll. One look when you let go. On scroll the pointer just moves with its target | Lag in drags and scrolls goes away | Same | 30 to 50% fewer | Low |
| 2 | Skip the look when nothing changed (text and small picture both the same) | A skipped look takes 0.05 s, not 2.1 s | Same | 10 to 25% fewer | Medium: a tiny change missed |
| 3 | Advance at once when you click the marked target, show a "looking" motion on the pointer, confirm with the look. Wait 0.4 s after a click instead of 1 s. Built only on steps that need just a click: see "What was decided" below | Feels under 0.5 s on a direct hit | Same | Same | Medium: a wrong advance must step back visibly |
| 4 | Send less: picture cut around the target, fewer elements, fixed part cached | 0.1 to 0.3 s faster | 0.9 to about 0.45 cents | Same | Medium: a dialog elsewhere is not seen |
| 5 | Tune the call: cap the answer length, retry a runaway answer, test less thinking on the recorded hard cases | 0.3 to 0.8 s faster, fewer 6 s looks | Same | Same | Accuracy may drop. Keep only if the recorded cases still pass |

Left out of the five: the small model as a first pass (it already failed once on "two steps at once"; worth a retry with a narrower question after change 5), and the live screen stream, because it needed your decision on the rule "he reads the screen only when called".

**What was decided.** On 13 November you put more than changes 1 to 3 in the MVP, as phase PS: changes 1 to 4, the cap and the retry from change 5, and the live screen stream. "Test less thinking" from change 5 was not decided and is not in the roadmap.

The screen watch (task PS.6). You approved it for the length of a guide. Its limits are in `04-architecture.md` 4.6, and that text counts. In short:

- It is used only to know when the screen has settled and whether it changed. The watch alone sends nothing to the model. A look is still made only after you act.
- It starts when the guide's steps are shown. It stops as soon as following stops: the last step is done, the card closes, you press Escape, you pause Phew, the limit of 40 looks is reached, or a look fails.
- First proposal: it also stops after 2 minutes without an action from you, and starts again when you act. Pause ends a running guide. See Open in `07-decisions.md`, screen watch.
- Frames stay in memory. They are never written to disk or to a log.

Change 3, the direct hit (task PS.3). The rule is in `04-architecture.md` 4.4. The Guide marks each step that needs only a click, with one yes or no field per step. Only on such a step does a direct hit advance at once. The look then confirms, and a wrong advance steps back. A direct hit is a press and release without a drag, inside the marked element, or inside the ring (22 points radius) around a marked point. Steps that need typing, dragging or choosing wait for the look. The last step always waits for the look, so the card never closes on a guess.

### Sources

- G2 https://platform.claude.com/docs/en/about-claude/pricing
- G5 https://platform.claude.com/docs/en/build-with-claude/vision
- G7 https://platform.claude.com/docs/en/build-with-claude/prompt-caching
- G9 https://platform.claude.com/docs/en/build-with-claude/fast-mode
- G10 https://platform.claude.com/docs/en/api/service-tiers
- G12 https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5-5
- G14 https://developer.apple.com/documentation/screencapturekit/scstreamframeinfo/dirtyrects
- G18 https://chromium.org/developers/design-documents/accessibility
- G19 https://www.electronjs.org/docs/latest/tutorial/accessibility
- G20 https://www.figma.com/blog/building-accessibility-into-a-canvas-based-product/
- G22 https://www.nngroup.com/articles/response-times-3-important-limits/
- G23 https://support.walkme.com/?p=1009
- G24 https://support.pendo.io/hc/en-us/articles/360033838131-Create-an-effective-dashboard-walkthrough
- G25 https://developer.apple.com/design/human-interface-guidelines/feedback
- G26 https://platform.claude.com/docs/en/build-with-claude/vision-coordinates

## 10.5 The Map for a general user

### What others do

- **The web standards are huge; only their top level is useful.** PROV-O needs three things to say who did what with what, when: a thing, an activity, an agent (P5).
- **Personal methods use very few categories.** PARA has four (P6). Zettelkasten has none, only notes and links (P7).
- **Tools with typed objects advise restraint.** Tana: merge or delete types you do not use (P9). Capacities: make a new type only when a group of notes has its own properties (P10).
- **Agent memories keep it small.** Zep ships nine default types and says: "Start with a small number of generic types", "Use few types, few fields, and short definitions", "Avoid category overlap" (P14). The reference memory server uses things, relations, and one-fact sentences (P16). Claude Code uses four kinds of note (P19).

### What goes wrong

- **Free links sprawl.** One test produced 981 relations with 966 different link names (P24).
- **Duplicates.** Cleaning removed 22% of the things in the same test (P24).
- **How many types a small model fills reliably: nobody has published a measurement.** This is the main unknown.

### Keeping facts true

Zep keeps dates on every fact. When a new fact contradicts an old one, the old one gets an end date and the new one wins; nothing is silently overwritten (P32, P33). Every fact traces back to where it came from (P34).

### Recall

Anthropic recommends a mix: "retrieving some data up front for speed", and a small set of search tools the model can use when it needs more (P27, P28). A search by the model costs one more request each time (P29).

### Proposal

Two levels: a few fixed classes, each with a free one-word "kind" (a course is a Project of kind course; a client job is a Project of kind client job). The research proposed nine classes and six links, with one catch-all class (Note) for any fact that is a sentence.

It also proposed building in two stages on the same tables: first Me, Project, Note and Tool with two links, to measure how reliably the small model writes; then the rest.

**What was decided.** On 13 November you chose differently on two points: eleven classes, with Event and Place added, and all of them built at once, not in two stages. A seventh link, "at", was then added so that a Place can be connected. That choice was delegated to Claude and waits for your confirmation (see `07-decisions.md`). The design that is built is in `05-map.md`. Where this part and `05-map.md` differ, `05-map.md` counts.

### Sources

- P5 https://www.w3.org/TR/prov-o/
- P6 https://fortelabs.com/blog/para/
- P7 https://zettelkasten.de/introduction/
- P9 https://outliner.tana.inc/learn/features/supertags
- P10 https://docs.capacities.io/reference/content-types
- P14 https://help.getzep.com/entity-types
- P16 https://github.com/modelcontextprotocol/servers/tree/main/src/memory
- P19 https://code.claude.com/docs/en/memory
- P24 https://arxiv.org/html/2502.09956v2
- P27 https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
- P28 https://www.anthropic.com/engineering/writing-tools-for-agents
- P29 https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview
- P32 https://help.getzep.com/facts
- P33 https://arxiv.org/html/2501.13956
- P34 https://help.getzep.com/graphiti/getting-started/overview
- P37 https://www.sqlite.org/fts5.html

Limits: no extraction was run, so every speed and size figure for recall is an estimate.

## 10.6 What this means for version 1

1. **Lead with memory, not with pointing.** Pointing is now common. "He knows your projects" is the open space.
2. **Say it honestly:** memory on your Mac, thinking in the cloud.
3. **The Map:** SQLite as planned, with full-text search, a small profile and the recent turns. No search by meaning yet. What was decided: eleven classes and seven links, all built at once. The research advised nine classes in two stages.
4. **Second brain:** a paste box is the smallest import that works, and the vendors' own method. What was decided: it is in version 1, together with reading Claude Code's `CLAUDE.md` and memory files on the Mac (phase PB). Reading export zips comes after the MVP.
5. **Agents:** read and research, with the five safety rules in 10.2. Saving the report as a new file in one folder is the only safe, small step beyond. What was decided: both are in the MVP (phase PA). How each rule is kept is in `03-experience.md` 3.6.
6. **Guide speed:** changes 1 to 3 remove most of the felt lag. This is an estimate, not measured. What was decided: more is in the MVP (phase PS): changes 1 to 4, the cap and the retry from change 5, and a screen watch during a guide. The size of the phase is in `06-sprint.md` 6.2.
7. **Time:** the research estimates read-and-research agents at 4 to 7 days, and 2 to 3 more to save the report as a file (10.2). These are estimates, not measured. You removed the deadline on 13 November so that nothing is cut.
