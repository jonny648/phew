# 5. The Map: storage, encryption, export

Sections 5.12 onwards of the Map design, split from `05-map.md` on 14 November 2026 with their numbers kept. The model (classes, links, defined terms, rules, recall, the Librarian, forgetting) is in `05-map.md` 5.1 to 5.11.

## 5.12 Storage

Two SQLite files on the Mac, in `~/Library/Application Support/Phew/`, beside `calls.log`: `map.sqlite` and `map-sensitive.sqlite`. Unit tests open a database in memory or in a temporary folder, never these files. Four tables, as before, with new columns, and a fifth, `forgets`, for Recently deleted. A sixth, `counter`, only in `map.sqlite`, holds one number: the highest id ever handed out, so an id is never used twice, even after a real delete. Added during the build of 14 November; in Postgres it becomes a sequence. The same shape can move to Postgres when the backend arrives. That move would change the rule "The Map lives only on the Mac" and needs your decision first. Your own Time Machine backup, if you use one, copies these files like any other. Your decision of 14 November: they stay in backups.

**Encryption.** The whole Map is encrypted, and sensitive facts get a second, separate lock. Your decisions of 14 November. The Map is two encrypted files with two keys: `map.sqlite` and `map-sensitive.sqlite`. Both use SQLite's rollback journal, not the write-ahead file. The tables below are the same in both files. The details are at the end of this section, "Encryption: the design".

| Table | Columns |
|---|---|
| `nodes` | id, owner, class, kind, name, aliases, text, properties, origin, source_event, confidence, sensitive, valid_from, valid_to, superseded_by, deleted, embedding, created, updated |
| `edges` | id, owner, from_node, to_node, link, strength, confidence, origin, source_event, valid_from, valid_to, superseded_by, deleted, created, updated |
| `events` | id, owner, time, app, kind, summary, project, mentions, sensitive, deleted, embedding |
| `terms` | name, query |
| `forgets` | id, time, label (the line the card showed, for the Recently deleted list) |

- `owner`, `from_node` and `to_node` are named this way because `user`, `from` and `to` are reserved words in SQLite or Postgres and cannot be plain column names. In the MVP `owner` holds the same value on every row. It is there for the day accounts exist.
- Ids are whole numbers. Dates are text in the ISO 8601 form.
- `text` holds the sentence of a Note.
- `properties` holds the few values special to a class, as JSON: a Task's `due` and `done`, an Event's `start` and `end`, a Document's `path` or `address`. Each value is stored with the origin that set it, which is what lets Priority be judged value by value (`05-map.md` 5.5).
- `aliases` holds other names for the same thing, including the name in another language, as a JSON list.
- `updated` is "last seen". `valid_from` and `valid_to` are "true from" and "true until". `superseded_by` is "replaced by".
- A history row (`05-map.md` 5.5) is a row in `nodes` with `valid_to` set and `superseded_by` pointing at the living row.
- `strength` is used only by "understands".
- Event kinds: ask, guide, tell, correction, task, import. A forget writes none.
- `mentions` is the list of ids of the things and Notes the past question mentions, stored as a JSON list. `project` is the id of its Project, or empty.
- `terms` holds each defined term of `05-map.md` 5.6 once: its name and the query that computes it, with its numbers. It is filled when the Map is created. Tuning a number is one row changed. "Next step" is the exception: code runs the other queries in the order `05-map.md` 5.6 gives.
- `deleted` is the list of ids of the forgets that put the row in Recently deleted, as a JSON list, or empty. Every read skips rows where it is not empty. Restore removes only its own id, so a row still hidden by another forget stays hidden.
- At the real delete (after 30 days, or on Delete now) the `forgets` row is deleted too, with the same secure delete, so its label leaves the file.
- `sensitive` (nodes and events) is yes or no, set by the Librarian's mark and by you. A past question is sensitive when it mentions a sensitive thing.
- The `embedding` columns stay empty in version 1.

### Text search

- Two text-search indexes, built into SQLite (FTS5): one over the name, aliases, kind and text of nodes, one over the summary of events. Each is updated in the same go as the row it indexes.
- The search ignores capitals and accents (the `unicode61` word splitter with `remove_diacritics 2`). No English-only word stemming, because you work in Italian and English.
- Phew's code never hands your sentence to the search as it is. SQLite would then demand that every word matches, and would stop with an error on a dot, a colon, a dash or an apostrophe. Instead the code:
  1. splits the question, the app name and the window title into words at every character that is not a letter or a digit, so `logo-v3.fig` becomes `logo`, `v3`, `fig`;
  2. drops single letters, and keeps at most 30 words (kept 14 November, tuned after the MVP test);
  3. puts each word in double quotes with a star after the closing quote, which is what makes it match the start of words;
  4. joins the words with OR: `"logo"* OR "v3"* OR "approved"*`.
- Results come back best match first (SQLite's own ranking), and a match in a name counts more than a match in a sentence. They are cut to the numbers in `05-map.md` 5.11. Only current facts are returned, unless the past is asked for.
- If no words are left, the search is skipped. If the search fails for any reason, it returns nothing and the answer goes on without it. The failure is logged without the words of the question.
- The name matching of `05-map.md` 5.9 uses the same index to find things with that name, then Phew's code compares the whole name. SQLite's own comparison does not ignore accents.
- Unit tests for P5.1 must include: a full sentence, a file name with a dot and a dash, a window title with a colon, a word with an apostrophe, an accented Italian word typed without the accent, and an empty question.

### Deleting for real

At the real delete after a forget or an undone import (after 30 days, or on Delete now), the deleted words leave the file, not only the tables:

- the database runs with `PRAGMA secure_delete = ON`;
- both text-search indexes have the FTS5 `secure-delete` option set to 1;
- there is no write-ahead file to empty, because the Map uses the rollback journal.

This needs SQLite 3.42 or later, and P5.1 checks the version. Tried on 14 November on a throwaway database with this Mac's SQLite 3.54: after these three steps a made-up name was no longer in the file. A unit test must repeat this: forget a made-up name, then look for it in the database file and its journal as raw text, on an unlocked test file (see "Encryption: the design").

### Encryption: the design

Approved by you on 14 November, after the research task P5.13. The research behind it is in `10-research-locking.md` 10.7.

**The choice**

**SQLCipher Community Edition 4.20.0** (27 October 2026, built on SQLite 3.54.1). Source: https://github.com/sqlcipher/sqlcipher/releases/tag/v4.20.0

It is the simplest way to meet all five of your needs. It is the same SQLite with every page encrypted, so text search and secure delete work as already designed. It carries its own SQLite 3.54.1, so the "3.42 or later" check no longer depends on the Mac's own SQLite. Stay on 4.x. By default the 5.0 betas cannot open 4.x files: https://github.com/sqlcipher/sqlcipher/releases/tag/v5.0.0-beta

**How it is added and built**

- In Xcode, add the package `https://github.com/sqlcipher/SQLCipher.swift`, rule "Exact version" `4.20.0`, to the Phew target. Source: https://github.com/sqlcipher/SQLCipher.swift/blob/master/Package.swift
- Set the Preprocessor Macro `SQLITE_HAS_CODEC=1` for Debug and Release. Source: https://www.zetetic.net/sqlcipher/ios-tutorial/
- Every Swift file that talks to the Map writes `import SQLCipher`. No file anywhere writes `import SQLite3`, and nothing links `libsqlite3`. Source: https://www.zetetic.net/sqlcipher/sqlcipher-apple-integrators/
- The Map is not built yet, so there is no plain database to convert. It is encrypted from the first day.
- From the terminal, `xcodebuild -project Phew.xcodeproj -scheme Phew build` fetches the package and builds. The package is a ready-made, signed framework. Source: https://github.com/sqlcipher/SQLCipher.swift/blob/master/Package.swift
- The licence asks for its notice where you can reach it, for example an "About and licences" item in the menu bar menu. Source: https://www.zetetic.net/sqlcipher/license/

**Two files, two keys**

- `~/Library/Application Support/Phew/map.sqlite` holds everything that is not sensitive. Key 1.
- `~/Library/Application Support/Phew/map-sensitive.sqlite` holds sensitive facts. Key 2.
- Both files have the same tables (5.12) and their own two text indexes. A sensitive node, its history rows (the "replaced by" chain), its links, its past questions, and the `forgets` row of any forget that includes a sensitive item all go into the sensitive file. `terms` lives only in `map.sqlite`.
- Phew opens `map.sqlite` with key 1, then attaches the second file with key 2 (`ATTACH ... AS s KEY ...`). Source: https://www.zetetic.net/sqlcipher/sqlcipher-api/
- Reads go through temporary views named `all_nodes`, `all_edges` and `all_events`, each joining `main` and `s`, created at every open. They do not reuse the table names, because a temporary view named `nodes` would capture writes meant for the real table. Writes always name their file (`main.` or `s.`). The queries in `terms` read the `all_*` views. Source: https://www.sqlite.org/lang_createview.html
- Ids come from one counter, so a sensitive row and a normal row never share an id.
- When a fact becomes sensitive, or stops being sensitive, it moves between the files in one transaction, then the old copy is securely deleted.
- If either file cannot be opened with its key, the Map does not open, and Phew says so. It never creates a new key over an existing file, and never deletes a file it cannot open.

**The journal: back to SQLite's default**

Use SQLite's default rollback journal instead of the write-ahead file (WAL). In WAL mode, a change across two attached files is safe only within each file: a crash can update one file and not the other. With the rollback journal, a change across both files is all or nothing. Source: https://www.sqlite.org/lang_attach.html

The rollback journal is encrypted with the database key, except a header that holds no data. Source: https://www.zetetic.net/sqlcipher/design/

Phew writes a few rows at a time, so WAL's speed gain is not needed. This also removes the write-ahead file from "Deleting for real".

**Keys**

- Each key is 32 random bytes from `SecRandomCopyBytes`, used only if it reports success. Source: https://developer.apple.com/documentation/security/secrandomcopybytes(_:_:_:)
- They are stored by Phew's existing `KeyStore` (Phew/Brain/KeyStore.swift), as generic passwords in the login Keychain, beside the Claude API key. Each key is stored as 64 hex characters.
  - Service: the bundle id, `com.gianlucatroietto.Phew`.
  - Account `map-key`: key 1, the whole Map.
  - Account `map-sensitive-key`: key 2, sensitive facts.
- They are passed as raw keys, the text `x'<64 hex>'`, which skips the slow step that turns a password into a key. Zetetic advises raw keys only for random keys like these. With `sqlite3_key`, pass that same text and its length, never the 32 bytes themselves; if Swift cannot see `sqlite3_key`, use `PRAGMA key`. Source: https://www.zetetic.net/sqlcipher/sqlcipher-api/
- Before use, the hex text is checked to be exactly 64 characters of `0-9a-f`. A malformed value would be taken silently as a password, and on a new file nothing would catch it.
- On first run each key is written to the Keychain and read back unchanged before its file is created. If the Keychain write fails, no file is created.
- The key is set before anything else on the connection. After it, Phew reads `sqlite_master` to prove the key is right. Source: https://www.zetetic.net/sqlcipher/sqlcipher-api/
- The key and any statement that contains it are never logged, never in an error message, and never in a file.
- Phew keeps one connection open, because opening is the slow part. Source: https://www.zetetic.net/sqlcipher/performance/
- Why the login Keychain: the newer data protection keychain needs the app signed with an App ID from a provisioning profile, and this project has none. Without one, every call fails with error -34018. Source: https://developer.apple.com/forums/thread/740164
- Builds signed "Apple Development" keep Keychain access across rebuilds with no prompt. A later move to Developer ID or App Store signing changes the signature: macOS then asks once per key whether Phew may use it, and if you click Deny the Map does not open. Builds signed only "to run locally" would ask on every build. Source: https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements

**What is encrypted and what is not**

Encrypted:
- Both files, every page, with AES-256 and a check that the page was not changed. Source: https://www.zetetic.net/sqlcipher/design/
- Their rollback journals. Source: https://www.zetetic.net/sqlcipher/design/
- SQLite's temporary data, which stays in memory in this build (`TEMP_STORE=2`). Source: https://www.zetetic.net/sqlcipher/design/

Not encrypted:
- The file names, sizes and dates, and a random 16-byte value at the start of each file. Source: https://www.zetetic.net/sqlcipher/design/
- The Map while Phew runs. It is in Phew's memory, and the hardened runtime blocks other apps from reading it. Source: https://developer.apple.com/documentation/security/hardened-runtime
- The Markdown export (P5.10). It is a plain file, saved only where you choose.
- `calls.log`. It holds no Map content by rule.
- The short-lived "super-journal" SQLite writes during a change that touches both files. It holds only the two journal file names, no Map content. Source: https://www.sqlite.org/atomiccommit.html
- `temp_store` is never set to FILE, so temporary data stays in memory.

**Text search for sensitive facts**

Sensitive facts can be searched by words. Their text index lives inside the sensitive file, behind key 2, so no word of theirs sits anywhere in plain text. Each search runs one query on each file's index and merges the results. The two indexes rank with their own statistics, so the merged order is approximate; the P5.1 tests check it on made-up data. Source: https://www.sqlite.org/fts5.html FTS5 is in the SQLCipher build. Source: https://github.com/sqlcipher/SQLCipher.swift/releases/download/4.20.0/SQLCipher.xcframework.zip

The search rules of 5.12 stay as they are. The export still leaves sensitive facts out unless you tick them.

**Deleting for real**

The steps of 5.12 stay, now on both files:
- `PRAGMA secure_delete = ON`. Run before the second file is attached, it also covers that file. The SQLCipher build does not turn it on by itself. Source: https://sqlite.org/pragma.html
- The FTS5 `secure-delete` option set to 1 on all four text indexes. Source: https://www.sqlite.org/fts5.html
- No write-ahead file to empty, since the rollback journal is used.

After a delete, any leftover on the disk is ciphertext. The steps above also mean that someone holding the key cannot recover the deleted item.

**Unit tests**

- Tests open `:memory:` with no key. The database stays plain, as in 5.12. The docs imply this but do not state it, so the first build proves it. Source: https://www.zetetic.net/sqlcipher/sqlcipher-api/
- Encryption tests use a temporary folder and keys made up inside the test. They never touch the real Keychain or `map.sqlite`.

**What you must know**

- **If a key is lost, the Map cannot be read, ever.** There is no recovery, by design. Source: https://www.zetetic.net/sqlcipher/sqlcipher-api/ Keys get lost when the login Keychain is reset, after a clean install, or on a new Mac set up without Migration Assistant.
- **Time Machine.** Both files and the login Keychain are backed up. A restore onto the same Mac should work. Since macOS 26.4, restoring the Keychain onto a different Mac is reported to fail, while Migration Assistant is reported to work. Source: https://eclecticlight.co/2026/09/14/how-can-you-copy-or-restore-keychains/
- **Old backups keep deleted items,** encrypted, readable by someone who has both the backup and the key. Local snapshots are kept up to 24 hours: https://support.apple.com/en-us/102154. To prevent this, the Map files can be left out of backups, but then there is no backup of the Map: https://developer.apple.com/documentation/foundation/urlresourcekey/isexcludedfrombackupkey. Your decision of 14 November: the files are backed up.
- **What the second lock does today.** Key 2 is a different key in the same login Keychain. A copy of `map.sqlite` with key 1 reveals no sensitive fact. Deleting key 2 erases every sensitive fact at once. But anyone who can use your unlocked Mac session opens both. A stronger lock would ask for Touch ID or your password before sensitive facts open. That needs the data protection keychain and a provisioning profile, and sensitive facts would be searchable only after you unlock them. Source: https://developer.apple.com/documentation/technotes/tn3137-on-mac-keychains Your decision of 14 November: not in the MVP. It is in the Later list (L15).
- It does not protect against someone using your unlocked Mac, malware you allow through a Keychain prompt, or an administrator. Keep FileVault on. Source: https://developer.apple.com/documentation/technotes/tn3137-on-mac-keychains
- About 5 to 15% slower than plain SQLite. Source: https://www.zetetic.net/sqlcipher/performance/

**What the builder verifies on the first build**

1. `xcodebuild -project Phew.xcodeproj -scheme Phew build` and `... test` fetch the package and pass from the terminal.
2. `otool -L` on the built app lists `SQLCipher.framework` and not `/usr/lib/libsqlite3.dylib`. `grep -rn "import SQLite3" Phew PhewTests` finds nothing.
3. At every Map open, `PRAGMA cipher_version` is not empty and starts with `4.20.0`, and `select sqlite_version()` returns `3.54.1`. If `cipher_version` is empty, Phew refuses to open the Map. A wrong link otherwise runs with no encryption: https://discuss.zetetic.net/t/important-advisory-sqlcipher-with-xcode-8-and-new-sdks/1688
4. The app launches from Finder, outside Xcode, with the hardened runtime on. The framework is signed by another team, so it must be embedded and re-signed ("Embed & Sign"). This is an inference, not tested.
5. Swift can see `sqlite3_key` with `SQLITE_HAS_CODEC=1`. If the macro does not reach Swift, add `-Xcc -DSQLITE_HAS_CODEC=1` to Other Swift Flags. If it still cannot, use `PRAGMA key`.
6. Opening with a different made-up key fails at the `sqlite_master` check.
7. Both files and any `-journal` file contain neither a made-up name nor a made-up sensitive fact as raw text. Neither file starts with `SQLite format 3`.
8. Secure delete is tested on a temporary file opened with SQLCipher and no key, so its pages are plain, with the same settings, rollback journal and FTS5 secure-delete option. Forget a made-up name, close the database, then search the raw bytes of the file and of any `-journal` file: the name must be absent. SQLCipher encrypts below the page layer, so the decrypted pages of a keyed file hold exactly what this plain file holds. Item 7 separately proves the keyed files hold no plain text. (Copying with `sqlcipher_export` would prove nothing: it copies live rows only.)
9. `PRAGMA s.secure_delete` returns 1, and `PRAGMA s.journal_mode` returns `delete`.
10. An accented Italian word typed without the accent is still found (`unicode61 remove_diacritics 2` under SQLCipher).
11. A move between the two files, interrupted by a forced quit, leaves the fact in exactly one file.
12. A test database in `:memory:` with no key behaves like plain SQLite. All existing unit tests pass.
13. The Keychain holds `map-key` and `map-sensitive-key` under `com.gianlucatroietto.Phew`. Check with `security find-generic-password -s com.gianlucatroietto.Phew -a map-key`, without `-g`, so the key is not printed. A rebuild gives no Keychain prompt.
14. No key, and no SQL that contains one, appears in `calls.log`, the system log or any error text.
15. Voice input, a guide and a task still work with the Map open, since Apple's own frameworks load the system SQLite. `cipher_version` still answers after them.
16. Time a Map open and one recall, and compare with plain SQLite on the same made-up data.
17. The licence notice can be reached from the menu bar.
18. `Package.resolved` is committed. The first `xcodebuild` needs the network to download the framework, which is checked against its checksum.
19. PhewTests runs inside Phew.app and uses the app's one copy of SQLCipher through `@testable import Phew`. The tests never write `import SQLCipher`, so the product is not linked to PhewTests: linking it copied a second framework into the test bundle. `otool -L` on the test bundle shows neither SQLCipher nor libsqlite3. Changed during the build of 14 November.
20. Under the tests, Phew does not open the real Map or read `map-key` at launch: the Map opens only when first needed, or not at all when running under XCTest.

## 5.13 Seeing and exporting it

The Map can be exported to one readable Markdown file: you, your projects with their tasks, people, documents and notes, then past questions by date. Each fact shows its origin. That is the Transparent value in the MVP, and the way to check what the Librarian wrote. The export is saved only where you choose, in the system folder window. Sensitive facts are left out unless you tick them. It is a copy outside the Map, so a later "forget that" does not reach it.

## 5.14 Later, and risks

Later versions:

- Search by meaning (embeddings).
- A nightly Keeper that merges duplicates and lowers old confidence.
- Reading export files of other assistants.
- A screen to manage kinds, and a view of the graph.
- Calendar access for Events.
- Facts learned from a research report, connected to the rest, with web findings added after an internal review.
- Links whose meaning changes with the matter or the setting. Research first.
- The Map kept on the Mac and in the cloud, on a personal page, divided by matter. This changes the rule "The Map lives only on the Mac".

Three biggest risks:

1. **Wrong writes pile up.** Eleven classes are more than any source has shown a small model to fill reliably, and all are built at once by your decision. Protection: the name, class and Project match in code, the fixed form the model must answer in and the code check behind it, the export to inspect, and a test set of made-up interactions with the expected writes.
2. **The search misses.** A question in Italian may not match a note in English, and a miss is silent. Protection: aliases, the links that come back with every result, and the model's own search can try other words.
3. **Old or planted facts in the profile.** Imports are the main way in. Protection: the tick list, low starting confidence, the stale label, imported text treated as data, and a research report that never writes to the Map.
