# 10. Research: The Map for a general user, and what it all means for version 1

Split on 14 November 2026 from what was one research file, one file per part, with section numbers kept. All parts are listed in `README.md`.

Done on 13 November 2026 by research agents on the web. Each fact carries a source number; the sources are listed at the end of the part. "Not confirmed" means the page could not be opened or the vendor does not say.

This file is the record of what the research found and advised. Where you decided differently, a line marked "What was decided" says so. Those lines were added on 14 November 2026. Where this file and the design documents differ, the design documents count.

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

**What was decided.** On 13 November you chose differently on two points: eleven classes, with Event and Place added, and all of them built at once, not in two stages. A seventh link, "at", was then added so that a Place can be connected. That choice was delegated to Claude and you confirmed it on 14 November. The design that is built is in `05-map.md`. Where this part and `05-map.md` differ, `05-map.md` counts.

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
5. **Agents:** read and research, with the five safety rules in `10-research-agents.md` 10.2. Saving the report as a new file in one folder is the only safe, small step beyond. What was decided: both are in the MVP (phase PA). How each rule is kept is in `03-experience.md` 3.6.
6. **Guide speed:** changes 1 to 3 remove most of the felt lag. This is an estimate, not measured. What was decided: more is in the MVP (phase PS): changes 1 to 4, the cap and the retry from change 5, and a screen watch during a guide. The size of the phase is in `06-sprint.md` 6.2.
7. **Time:** the research estimates read-and-research agents at 4 to 7 days, and 2 to 3 more to save the report as a file (`10-research-agents.md` 10.2). These are estimates, not measured. You removed the deadline on 13 November so that nothing is cut.
