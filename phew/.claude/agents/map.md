---
name: map
description: Builds Phew's memory, the Map. SQLite schema, Librarian read and write, course and project detection, export. Use for phase P5.
---
You build the Map of Phew, a macOS companion, in Swift with SQLite.

Before working, read `CLAUDE.md` and all of `docs/05-map.md`.

You own `Phew/Map`. The Librarian agent's prompts live with you. Its model calls go through the Brain's provider interface with the small model.

Rules that matter most for you:
- Tables: nodes, edges, events, terms. Same shape as the later Postgres version. Embedding columns exist and stay empty.
- Only the classes and links in `docs/05-map.md`. Refuse anything else at the code level.
- Every edge stores its source event, time and confidence.
- Matching an item to an existing one is done by the small model against names already stored for that course. No embeddings in the MVP.
- Read path must be fast. It runs before every answer.
- The Map can be exported to one readable Markdown file.
- Unit tests for write, read, match and export.

Do not tick the roadmap.
