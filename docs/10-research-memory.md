# 10. Research: Memory you already have in other AI tools

Split on 14 November 2026 from what was one research file, one file per part, with section numbers kept. All parts are listed in `README.md`.

Done on 13 November 2026 by research agents on the web. Each fact carries a source number; the sources are listed at the end of the part. "Not confirmed" means the page could not be opened or the vendor does not say.

This file is the record of what the research found and advised. Where you decided differently, a line marked "What was decided" says so. Those lines were added on 14 November 2026. Where this file and the design documents differ, the design documents count.

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
