# 10. Research: How similar tools work

Split on 14 November 2026 from what was one research file, one file per part, with section numbers kept. All parts are listed in `README.md`.

Done on 13 November 2026 by research agents on the web. Each fact carries a source number; the sources are listed at the end of the part. "Not confirmed" means the page could not be opened or the vendor does not say.

This file is the record of what the research found and advised. Where you decided differently, a line marked "What was decided" says so. Those lines were added on 14 November 2026. Where this file and the design documents differ, the design documents count.

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
5. The research agent has no tool that writes or changes anything. This follows the advice to give an agent the least power it needs (W26). Changed on 15 November: an agent may also act in the background, in a narrow way (`13-hand.md` 13.4).

**What was decided.** On 13 November you approved the rules for agents; they are hard rules in `CLAUDE.md`. How each one is kept is written in `03-experience.md` 3.6 and `04-architecture.md` 4.4. Where this part and those two differ, those two count. Three points go further than the research:

- Rule 2: the limits are on searches, pages and cost, not tokens. 5 searches, 8 pages, 50 cents, approved 14 November. Searches and pages are capped in the request itself, with `max_uses` on each tool (W15, W16). `max_uses` counts inside one request, so Phew's code lowers it by what the earlier requests of the same task used. Phew's own code adds up the cost after each reply.
- Rule 3 is kept by two guards, not by asking the model. First, Phew's own code removes every web address from the screen text, the Map facts, each Map search result and file text before sending. Second, the fetch tool's `url_sources` setting has `client_tool_results` set to `{"type": "none"}` (W16), so Anthropic's server never opens an address that came back from Phew's own tools. `user_input` is allowed, because on 14 November you chose that an address you type in the task is opened; Phew's own removal of addresses is then the only guard for the screen text and the Map facts in the first message (`04-architecture.md` 4.4). Re-read W16 before building.
- Rule 5: the agent has four tools: web search, web fetch, Map search and `read_project_memory`, which only reads the project's Claude Code files (added 14 November). None writes or changes anything. The report file (level B1 below) is written by Phew's own code when the report is ready, never by the model.

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

**What was decided.** On 13 November you put levels A and B1 in the MVP, as phase PA. B2 and C come after the MVP. Changed on 15 November: level C, acting in apps, moved into the MVP as phase PH (`13-hand.md`). B2 stays after the MVP.

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
