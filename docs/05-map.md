# 5. The Map

Phew's memory of your work: what you are working on, with whom, with what, what was decided, and what you asked him before. It lives in two encrypted files on your Mac. They are never uploaded or synced. The few facts an answer needs are sent to the model together with your question.

Rewritten on 13 November 2026 for a general user. The first version was built around one student (Course, Assignment, Concept, Lecture). The research behind this version is in `10-research-memory.md` 10.3 and `10-research-map.md` 10.5. Completed on 14 November 2026 after the review of phase PR: the design is the same, and the points a builder would have had to guess are now written down.

## 5.1 Principles

| Principle | Where it comes from |
|---|---|
| Start from the questions the Map must answer | Your ontology study |
| Few fixed classes, each general. Variety comes from a free word, the "kind" | Zep, Tana, Capacities: few, generic, non-overlapping types |
| Fixed links only. No "related to" | A test with free links produced 966 link names out of 981 |
| A fact that fits nowhere is kept as one sentence, a Note | Reference memory server, Graphiti |
| Every fact says where it came from and since when it is true | Zep, PROV-O |
| Nothing is silently overwritten. Forgetting acts at once, waits 30 days in Recently deleted, then is a real delete | Your decisions of 13 and 14 November |
| Define each term exactly once | Your ontology study |
| The model proposes. Phew's own code checks, counts and writes | Review of 14 November |

Left out, as before: OWL, RDF, SPARQL, formal reasoning engines, warehouse tools, enterprise governance.

## 5.2 Competency questions

The Map exists to answer these. If a class or link does not help answer one, it is not added.

1. What is this on my screen, in terms of what I am working on?
2. Where did I leave off on this project?
3. What did the client ask me to change on the landing page?
4. Which file has the logo version they approved?
5. What have I still not understood in this course?
6. What is due this week, and what does it need?
7. What did we decide about pricing, and when?
8. Who is Marta, and what am I doing with her company?
9. How did I fix this error last time, and which tool do I deploy with?
10. How do I like things done? (language, tone, format)
11. What do you know about me, and where did you learn it?
12. What should I do next?
13. When and where is the next review, and who will be there?

## 5.3 Classes

Eleven fixed classes. Each thing also has a **kind**: one free word that says which sort it is.

| Class | Meaning | Example (kind) | Needed by question |
|---|---|---|---|
| Me | You. One row, made when the Map is created. It is never deleted | | 10, 11 |
| Project | Work with a goal | Typography 2 (course), Acme rebrand (client job), Phew (product) | 1, 2, 12 |
| Task | Something to finish. May have a due date | Poster brief (assignment), Fix login bug (bug) | 6, 12 |
| Topic | An idea, a skill or a problem | Kerning (concept), CORS error (error) | 1, 5, 9 |
| Document | A named file, page or recording | logo-v3.fig (design file), Lesson 4 slides (slides) | 1, 4 |
| Person | Someone you work with | Marta (client), Prof. Rossi (lecturer) | 3, 8, 13 |
| Organization | A company, school or team | Acme (client), your design school (school) | 8 |
| Tool | An app, site, language or command | Figma (app), Vercel (service), Swift (language) | 9 |
| Event | Something that happens at a time | Review with Marta on 20 Nov (meeting), Lesson 4 (lecture) | 13 |
| Place | Where something is or happens | Room B12 (room), Milan office (office) | 13 |
| Note | One fact, one sentence | "Client approved logo v3" (decision), "Answer in Italian" (preference) | 3, 4, 7, 9, 10, 11 |

How to tell them apart, so the classes do not overlap:

- **Task or Event.** A Task is something *you finish*; its date is a due date. An Event *happens* at a time whether or not you do anything. A deadline is the due date of a Task, not an Event.
- **Event or Document.** A lecture is an Event. Its slides or recording are Documents, linked to it with "part of".
- **Topic or Note.** A Topic is a thing you can understand or not ("kerning"). A Note is a statement ("kerning is set per pair in InDesign").
- **Tool or Topic.** A Tool is something you open or run (Figma, Swift, git). What you are learning about it is a Topic with its own name ("Swift optionals", "auto layout"). "Understands" points to the Topic, never to the Tool.
- **Tool or Organization.** The product is a Tool (Figma, Vercel). Its company is an Organization only when you work with it or for it, as a client, employer or school.
- **Topic or Task.** A problem that can come back is a Topic ("CORS error"). Fixing it this time is a Task ("Fix login bug"), and the Task can require the Topic.
- **Note is the last resort for things, the first for statements.** If it is a sentence, it is a Note about the things it mentions.

Events and Places come only from what you tell Phew, what is on screen when you call him (through his answer, never the window text itself), and what you import. He has no access to your calendar.

From the old design: Course is now a Project of kind "course". Assignment is a Task. Concept is a Topic. Source is a Document. Lecture is an Event with its Documents. App is a Tool. Session is no longer a class: the events table already records each time you worked with him.

Two words that look alike: an **Event** (capital E) is a thing in the Map, such as a meeting. An **event** in the events table is one time you worked with him. This document calls the second one a "past question" where it could be confused.

### Kinds

A kind is one lower-case word or short phrase. The Librarian is shown the kinds already in use and this starting list, and reuses one before inventing one.

| Class | Starting kinds |
|---|---|
| Project | course, client job, product, thesis, personal |
| Task | assignment, bug, delivery, chore |
| Topic | concept, skill, error, question |
| Document | design file, slides, document, web page, code, recording |
| Person | client, lecturer, teammate, friend |
| Organization | client, school, company, team |
| Tool | app, service, language, command |
| Event | meeting, lecture, review, release |
| Place | room, office, city, venue |
| Note | decision, preference, instruction, identity, fix, reference, unconfirmed |

No defined term depends on a kind, and no rule depends on a kind the Librarian chose. So a new or misspelled kind breaks nothing. One kind is written by Phew's own code, never by the Librarian: "unconfirmed", for the weaker side of a disagreement (5.5).

## 5.4 Links

Seven fixed links. A link goes one way, from the first thing to the second.

| Link | From, to | Example |
|---|---|---|
| part of | Task, Document, Event or Project to Project. Document to Event. Person to Organization | Poster brief, part of, Typography 2 |
| about | Note to anything. Document or Event to Topic | "Client approved logo v3", about, logo-v3.fig |
| requires | Task to Topic or Document. Topic to Topic | Poster brief, requires, Kerning |
| involves | Project, Task or Event to Person or Organization | Acme rebrand, involves, Marta |
| uses | Project to Tool | Acme rebrand, uses, Figma |
| at | Event or Organization to Place | Review with Marta, at, Milan office |
| understands | Me to Topic, with a strength from 0 to 1 | Me, understands, Kerning, 0.3 |

There is no "related to". When no link fits, the fact is written as a Note about the things it mentions.

The seventh link, "at", was added with the Event and Place classes so that a Place can be connected. "Document to Event" was added to "part of" on 14 November, so that slides can be tied to their lecture. Both approved on 14 November. Links whose meaning changes with the matter or the setting are an idea for after the MVP (`05-map-storage.md` 5.14).

Phew's own code checks both ends of every link against this table before writing. A link whose ends are not listed here is dropped.

**The strength of "understands"** is set by Phew's own code, never written by the model:

- The first time you ask about a Topic, the link is created at 0.3.
- Each later question about that Topic lowers it by 0.1, down to 0.
- When you tell him you understand it, it becomes 0.9. When you tell him you do not, it becomes 0.
- When one question both mentions a Topic and says whether you understand it, what you said wins: the strength becomes 0.9 or 0, and no 0.1 is taken off for that question.
- The Librarian only reports what you said about a Topic: understood, not understood, or nothing said. It never writes the number.
- A change of strength updates the link in place. It keeps no history row: it is a counter, not a statement.

"A question about a Topic" means a past question of kind ask or guide that mentions the Topic.

## 5.5 What every fact carries

Every thing and every link stores:

| Field | Meaning |
|---|---|
| Origin | **told** (you said it to him), **observed** (he learned it while answering), or **imported** (from another AI tool) |
| Source | The past question or import that produced it. This is how he answers "where did you learn that?" |
| Created | When it was stored |
| True from, true until | An empty "true until" means still true |
| Replaced by | On an old version only: which fact took its place |
| Confidence | 0 to 1 |
| Last seen | The last time something confirmed it |

Rules:

- **Starting confidence.** Told 0.9, observed 0.6, imported 0.5. Seeing the same fact again raises it by 0.1, up to 0.9. You confirming it sets it to 1. Confidence is always set by code from the origin, never by the model. It is used for one thing: between two results that match equally well, the more confident one comes first, in recall and in the profile. It is also shown in the export. All these numbers were kept on 14 November and are tuned after the MVP test.
- **Replacing a thing.** A thing keeps one row and one id for its whole life, so its links, the Notes about it and the past questions that mention it stay attached. When one of its values changes (its name, its kind, a due date, done or not, a start time, a path), the old values are first copied into a history row, with "true until" set and "replaced by" pointing at the living row. The living row then takes the new value, with the "true from" of the new fact.
- **Replacing a Note or a link.** The other way round: the old row gets "true until" and "replaced by", and a new row is added. The links of an old Note end with it.
- Either way the old version is kept as history, so he can answer "what was the deadline before?". No link ever points at a history row.
- **Priority.** Told beats observed, observed beats imported. Equal origins: the newer one replaces the older one. A weaker source never replaces what a stronger one said. What it says is kept beside it as a Note of kind "unconfirmed" about the same thing, with its own origin and confidence. Answers use the stronger one. If the weaker fact is observed and newer, the Guide adds one line saying so. An imported one is not mentioned.
- **Priority is judged value by value.** If you told him a Task's due date, something he observed cannot change that date. It can still mark the Task as done, because nobody had stated that. A value nobody has stated yet can be filled by any source.
- **Correcting.** "No, the deadline is the 20th" is a told fact that replaces the old one.
- **Only current facts are used** in answers, unless you ask about the past.

### Forgetting

"Forget that" acts at once. The forgotten thing waits 30 days in Recently deleted, where you can restore it. After 30 days it is wiped for real. Your decision of 14 November.

- **Who can start it.** Only your own words to him. Text on the screen, on the web, in a file or in an import never can.
- **What "that" is.** The thing or the Note you name ("forget Marta", "forget that I like short answers"). If you name nothing, it is what the last answer was about, while that answer is still in working memory. If more than one fits, or he is not sure, he asks which. He never guesses.
- **He does not ask first.** He forgets at once and the card names what went, for example: "Forgot Marta: 1 person, 4 notes, 3 links, 6 past questions. In Recently deleted for 30 days."
- **What goes.** The thing, every past version of it, its links, and the Notes about it with their past versions.
- **Recently deleted.** From the moment of the forget, all of that is hidden from answers, from recall and from the export, and taken out of both text-search indexes. Past questions that mention it are hidden the same way. A menu entry "Recently deleted" lists each forget with the days left, and a Restore button that puts everything back as it was, indexes included. It also has "Delete now", for something you want gone at once (first proposal).
- **After 30 days**, or on Delete now, the real delete runs. Every past question that mentions it loses that mention and its summary, because the summary could still hold what you asked him to forget. The emptied row is deleted too, unless it still mentions something else or another fact has it as its source. So other facts keep their source, and an import can still be undone. The check for items past 30 days runs when Phew starts and once a day while he runs.
- **What stays.** Things that were only linked to it stay, without the link. Me is never deleted: you forget single facts about you.
- **No trace of the request.** The forget writes no past question and no fact. The profile is rebuilt and the working turns are cleared at once.
- **Wiped, not only hidden.** At the real delete the words are overwritten in the Map's file and taken out of the search indexes. See `05-map-storage.md` 5.12.
- **The name used elsewhere.** After the forget he searches the Map for the name. If another sentence still contains it, the card says how many, and you can forget those too.
- **What it cannot reach.** Exports and reports you already saved, backups of the Mac such as Time Machine, and what was already sent to the model in earlier questions.

The card's wording, the hiding of past questions during the 30 days, and "Delete now" are first proposals.

## 5.6 Defined terms

Written once. Agents use these and never invent their own meaning.

| Term | Definition |
|---|---|
| Current | "True until" is empty |
| Open (for a Task) | Current and not marked done |
| Active | A Project with a past question in the last 14 days |
| Due soon | An open Task with a due date within the next 7 days, or already late |
| Coming up | An Event that starts within the next 7 days |
| Stale | A current fact not seen for 90 days and not told by you. Shown as "may be outdated" |
| Open point | A Topic mentioned in at least two past questions of kind ask or guide, whose "understands" strength is below 0.5 |
| Next step | The first open Task that is due soon, earliest date first; else the open Task with the oldest "last seen" in the Project your question matches (with no match, the Project with the latest past question); else the summary of the last past question on that Project |

Who computes them: Phew's own code, each time the Map is read. No model is asked and nothing is stored in advance. Which recall layer runs which term is in 5.11.

The open points of one Project are the open points mentioned in a past question on that Project, or required by one of its Tasks.

The numbers (14 days, 7 days, 90 days, 0.5, and the strength values 0.3, 0.1, 0.9 and 0) are first proposals. You kept them all on 14 November; they are tuned after the MVP test.

## 5.7 Rules, not reasoning

Four simple rules instead of an inference engine.

- If a Task requires a Topic that is an open point, the Guide starts from that Topic.
- If a Task is due soon, it becomes the answer to "what next". It is never pushed as a popup.
- If a fact is stale, the Guide may use it but says it may be outdated.
- If two current facts of the same origin contradict each other, the Guide says so and asks, and does not pick one silently. When the origins differ, the Priority rule in 5.5 decides.

How each rule reaches the Guide: the first three are computed by code and arrive inside recall (5.11), as the line "Start from: Kerning (open point)", as the next step, and as the words "may be outdated". The fourth is an instruction in the Guide's prompt, because only the model can tell that two sentences disagree. Recall gives it what it needs: every line shows its origin and date.

## 5.8 Four memories

| Memory | Holds | Lives |
|---|---|---|
| Working | The last 3 questions and answers of the current conversation, as text only, for follow-up questions. Never the screen text or the picture of an earlier turn: a follow-up takes a fresh look | In memory only. Dropped 5 minutes after the last answer, and on Quit |
| Profile | A short summary of you: your name, current Notes about Me (told first, then observed, then imported), then active Projects with their Tasks due soon. Each line says where it came from | Built by Phew's own code when a question arrives, with no model call. The same facts always give the same text, in the same order. At most about 200 lines |
| Episodic | Past questions: what you asked, what he answered in one or two lines, when, in which app, on which project | Events table |
| Semantic | The Map: things and links | Nodes and edges tables |

3 turns, 5 minutes and 200 lines were kept on 14 November; they are tuned after the MVP test.

## 5.9 How it is filled

The model proposes what to write. Phew's own code checks every line and does the writing.

### After an answer

1. When the answer is done, the Librarian (small model) runs in the background. The card does not wait for it. It runs once per question, after an explanation or after the first answer of a guide. It does not run after the Follower's looks during a guide.
2. The Librarian is sent:
   - your question;
   - his answer, as text: the explanation and, for a guide, the steps;
   - three labels: the app name, the window title, and the open document's name with its path or address when known;
   - today's date;
   - the stored facts that recall found for this question (layer 2 in 5.11), numbered f1, f2 and so on;
   - the kinds in use and the starting list.

   It is never sent the window text, the picture or the list of things on screen. Everything it is sent has passed the secrets filter.
3. In one call it answers in a fixed form, the same kind of form the Conductor and the Guide already answer in. The form is below.
4. Phew's own code checks every line. The checks are below.
5. Phew's own code then checks each new thing against the Map by name. See "Name matching" below.
6. Everything is written in one go: the facts, one row for the past question (its summary, the Project, and the things it mentions), and the "understands" strengths from 5.4. If the call fails or the answer is not in the form, nothing is written. The failure is logged without any words from the question.
7. There is no nightly clean-up in version 1. Stale is computed when reading.

Cost: one small-model call per answer. Estimated from the price table in the code at about a twentieth of a cent. Not measured.

### The Librarian's fixed form

| Part | What it holds |
|---|---|
| Things | For each: a short label used only inside this answer (t1, t2), class, kind, name, other names, and the class's own values: due and done for a Task, start and end for an Event, path or address for a Document. For a Topic: whether you said you understand it (yes, no, or not said) |
| Notes | For each: the sentence, its kind, and what it is about, as labels or fact numbers |
| Links | For each: from, link, to. Six names can be chosen: `part_of`, `about`, `requires`, `involves`, `uses`, `at`. "Understands" is never written by the Librarian |
| On every thing, Note and link | `new`, `same` as a stored fact, or `replaces` a stored fact, with that fact's number (f3). Told or observed. And a date, when your words give one ("since Monday") |
| Once per answer | A summary of one or two lines. The Project this was about, if any. On the remember route only: the numbers of the facts you asked him to forget, a question back to you when he is not sure which one you mean, and one line for the card |

For the builder: every field is always present. A value the Librarian does not know is an empty text, so the form has no optional fields and stays inside the limits of the Claude API's structured outputs. Class and link names are compared ignoring capitals.

Told or observed: **told** only when your own words in the question state the fact, such as "remember that the client wants the logo in blue" or "I prefer short answers". Never because of text on the screen or in a file. "Imported" is never chosen here: only an import sets it (5.10).

### What the code checks

The form can only limit a field to a list of names. The rest is checked by code, and nothing is guessed:

- A class or link name outside the lists is dropped.
- A link whose ends are not the classes listed in 5.4 is dropped.
- A fact number that was not in what the Librarian was sent is dropped. So is a label that no thing defines.
- A date that cannot be read is left empty. "True from" is the date the Librarian gave, otherwise the time of the question.
- Me is never created. There is one Me row.
- The Project of the past question is the one Phew's code detected (5.11). Only when it detected none is the Librarian's own answer used.
- A Note about nothing is linked to the Project of the question, when there is one.
- A sentence equal to a current Note, ignoring capitals and accents, is not stored twice. It counts as seen again.
- A web address is stored without anything after `?` or `#`.
- The Priority rule in 5.5 is applied here, by code.
- Everything passes the secrets filter again before it is written.
- A request to forget is read only on the remember route, and never deletes by itself: see "Forgetting" in 5.5.

### Name matching

For each thing the Librarian marks as new, the code looks for an existing current thing:

- of the same class,
- with the same name or alias, ignoring capitals and accents,
- and, for a Task, a Document or an Event, in the same Project. When the new thing has no Project, any Project matches.

For a Document with a known path or address, the path or address decides, not the name.

If one is found, it is reused, whatever the model said. If several are found, the one seen most recently is reused. The same name in another class or another Project is a different thing: a new one is created.

Limit: two different people stored under the very same name are still treated as one, until you correct him or give a fuller name.

### When you tell, correct or forget

These go through the Conductor's "remember" route, and the Guide does not answer.

- **Telling or correcting.** The same steps run, without an answer. The stored facts sent to the Librarian come from a search with your words. The card then shows one line that names what was stored or replaced. If nothing passed the checks, the line says nothing was stored.
- **Forgetting.** The Librarian only points at the stored facts you mean. If you named nothing, it is also sent what the last answer was about. Phew's own code then forgets at once and the card names what went, as written in 5.5.
- **Asking what he remembers** ("what do you know about me?") is a normal question. The Guide answers it with recall (5.11).

A question that also states a fact ("the deadline is the 20th, what do I do first?") is a question. The Librarian picks up the fact after the answer, as told.

### After a research task

Phew's own code writes one past question of kind "task": your task cut to one line, and the Project. The report is not sent to the Librarian in version 1, so nothing read on the web becomes a fact in the Map.

### What is never stored

- The window text and the picture. From what he sees, the Map keeps only labels: the app name, and a file's name and path or a page's address. The window title is shown to the Librarian and is kept only when it becomes the name of a Document. Everything else the Map keeps is what Phew learned, in his own words.
- Anything the secrets filter removes.
- Passwords and other secrets: the secrets filter removes them before anything is sent, so the Librarian never sees them.

Sensitive things seen on screen (health, money, other people's private messages) are written like any other fact, and marked sensitive by the Librarian. Your decision of 14 November. A sensitive fact gets a second lock on top of the encryption of the whole Map (`05-map-storage.md` 5.12), and is left out of the export unless you tick it. Marking rests on the Librarian's judgement, so it is tested in P5.2. How the lock works is decided after the P5 research task.

You approved keeping these labels on 14 November. The capture rule in `CLAUDE.md` now says so.

## 5.10 The second brain: imported memory

What your other AI tools already know about you, brought into the Map. There are two ways in. Both end in the same tick list.

### The paste box

1. You paste the memory list your assistant wrote. Nothing is sent until you confirm.
2. The secrets filter runs first.
3. The small model is told that the text is data and not instructions. It answers in a fixed form: a plain list of facts. For each fact: one sentence, a kind, the things it names (class, kind, name), a date if the text gives one, and whether the sentence is written as an instruction for an assistant. A long text is cut at paragraph breaks into several calls, about 20,000 characters each (kept 14 November, tuned after the MVP test).
4. You see the list and tick what to keep. Nothing is written to the Map before you tick. Unticked facts are dropped, and so is the pasted text.
5. Each ticked fact becomes a Note with origin "imported", about Me or about the things it names. New things are created when needed, through the name matching in 5.9, also with origin "imported".
6. One import is one row in the events table, of kind "import". Its summary says only where it came from and how many facts, never their words.
7. A date in front of a pasted fact becomes its "true from" date. With no date, it is the day of the import.
8. An imported fact never replaces something you told him or he observed. See Priority in 5.5.
9. A fact written as an instruction starts unticked, because it was written for another assistant.

### Claude Code's files

1. You choose a project folder. Phew reads `CLAUDE.md` in it, and `.claude/CLAUDE.md` if there is one.
2. He then looks for that project's memory files himself. Claude Code keeps them in a hidden folder in your home folder, `~/.claude/projects/<project>/memory/`, so you never have to find it. He lists the projects there that have memory files, with the one that matches your folder already chosen, and you pick.
3. He reads only those two things: the `CLAUDE.md` files, and the `.md` files directly inside that `memory` folder. He never reads conversation transcripts (`.jsonl`), settings, or any other file, and he does not follow shortcuts (aliases or links) that point outside.
4. Before anything is sent he shows the list of files he will read and their total size. Nothing is sent until you confirm.
5. Each file then goes through steps 2 to 9 of the paste box, one call per file.

If you choose Claude Code's own folder, `~/.claude`, its `CLAUDE.md` is your personal one. Its facts are about Me.

What each file becomes:

| File | Becomes |
|---|---|
| Memory file of type `user` | Notes about Me |
| Memory file of type `feedback` | Notes of kind "preference". Unticked by default, because it is advice written for a coding agent |
| Memory file of type `project` | A Project and Notes about it |
| Memory file of type `reference` | Notes of kind "reference" |
| Memory file with no type | Sorted like pasted text |
| `MEMORY.md` | Skipped. It is only the index of the other memory files |
| `CLAUDE.md` (it has no type) | Notes of kind "instruction" about the Project named after the folder. Unticked by default, because it is written as rules for a coding agent |

"True from" is the date in the file's header when it has one. Otherwise it is the date the file was last changed on disk.

**When an answer needs them.** Besides an import, the Guide and the Runner can read the current project's `CLAUDE.md` and memory files with a read-only tool, `read_project_memory`, when a question or a task needs them. Only the files named in step 3, only for the Project the call is about, and only after you have pointed Phew at that project's folder once. The text passes the secrets filter and is data, never instructions. Nothing is read in the background, and nothing read this way is written to the Map. Your decision of 14 November.

Not checked yet, so the builder must look at real files on a Mac when building PB.4: the name Claude Code gives the hidden project folder, and the exact header lines of a memory file (the `type` line above). Neither is documented as fixed. Tests use made-up copies.

### Undoing an import

"Undo last import" in the menu removes every fact that came from the last import, at once, like a forget: the card names what went, and it waits 30 days in Recently deleted. A thing the import created is kept if something you told him or he observed now points to it. The real delete is wiped from the file like a forget (`05-map-storage.md` 5.12). Last import only in version 1. Approved 14 November.

### Not in version 1

Reading the export files of ChatGPT or Gemini: no export of theirs has a documented format.

Changed on 15 November: Claude's memory export is read, and is the main way to import (roadmap PB.4). It is a zip or folder of Markdown files: `profile.md`, `preferences.md`, `areas/`, `topics/` and one folder per project under `projects/`. The place of a file decides what its facts attach to; the file's text is data.

The paste box, the tick list and the file list are small panels you open from the menu. The folder is picked in the system folder window, the one written exception to the focus rule. Both approved 14 November.

## 5.11 Recall: when called or needed

| Layer | What | Cost |
|---|---|---|
| 1. Always loaded | The profile, and the last turns of the conversation (5.8) | No wait. An estimated 500 to 1,500 tokens for a usual profile, more near the 200-line limit. Cheaper once caching is built, see below |
| 2. Before every answer, by Phew's own code | The Project this is about, its last 3 past questions, and up to about 6 Notes or things found by a text search with your question, the app name and the window title. Also, with no search, the lists from the defined terms in 5.6: the Tasks due soon, the Events coming up, the next step, and the open points of that Project. At most 3 lines each. An empty list adds nothing | A few milliseconds, estimated. No model call. An estimated 400 to 1,500 tokens |
| 3. By the model, when it needs more | One search tool, `search_map`. Given to the Guide and the Runner, never to the Follower. They also get `read_project_memory` (5.10) | One more request each time it is used: an estimated 1 to 3 seconds more before the first word, and the question, the picture and the screen text are sent a second time |

- **When needed** is layer 2: memory appears without you asking.
- **When called** is layer 3 and plain questions: "what do you know about me?", "what did we decide about pricing?".
- Everything recall hands to a model has passed the secrets filter.

**Which layer runs which defined term.** Current is a filter on every read. Open is used inside due soon and next step. Active is used to build the profile. Due soon, coming up, next step and open point are run by layer 2 before every answer and can be asked for in layer 3. Stale is a mark on a result line, in both layers.

### What a result looks like

Layer 2 and `search_map` use the same format. Each result is one line, and it reads the links, not only the words. It gives:

- the name, class and kind; for a Note, its sentence;
- its dates: "true from", and the due date or start time when it has one;
- where it came from, in words: "told on 12 Nov", "observed on 12 Nov in Figma", "imported on 13 Nov";
- "may be outdated" when it is stale, and "late" for a Task past its due date;
- its current links one step away, written with names: "part of Acme rebrand, at Milan office, involves Marta". At most about 8 links per result, the newest first.

A result for a thing also lists up to 3 current Notes about it, the newest first. This is how a Note that does not contain the thing's name is still found.

Example: "Review with Marta (Event, meeting). Starts 20 Nov 15:00. Told on 12 Nov. Part of Acme rebrand, at Milan office, involves Marta."

A past question comes back as its date, app, Project and summary. One with an emptied summary (after a forget) is skipped.

Never internal ids. For the Runner, web addresses are left out of every line.

### The search tool

`search_map` takes:

| Argument | Meaning |
|---|---|
| `query` | The words to look for. May be empty when `list` is used |
| `class` | Optional. One of the eleven class names, or `History` to search only past questions |
| `since` | Optional. A date: only facts true from that day, and past questions from that day |
| `list` | Optional, in place of a query. One named list: `due_soon`, `coming_up`, `open_points`, `next_step`, `stale`, `about_me` |
| `past` | Optional, yes or no. Yes also returns old versions, each with the dates it was true |

It returns at most 10 results (kept 14 November, tuned after the MVP test). The lists are fixed, and the tool's definition is identical on every call. List and class names are compared ignoring capitals. An unknown name returns nothing.

### Project detection

This is the first thing layer 2 does (roadmap P5.6). Phew's own code, no model call:

1. If the open document's path or address is the path or address of a stored Document, the Project is the one that Document is part of.
2. Otherwise, a text search of the names and aliases of Projects and Documents, with the app name, the window title and your question. The best match gives the Project.
3. Otherwise no Project is named. He does not guess.

The path of the open document is not in the context packet today. Senses adds one field for it, passed through the secrets filter like every other string. Not every app gives one: check per app when building.

Correcting him: "this is the Acme project" is a told fact. The Librarian links the open Document to that Project with "part of", so the next call from the same file finds it at step 1.

### What is not built yet

Today the Brain sends one question and gets one answer: no tools, no earlier turns, no caching. Recall needs the changes below inside the Brain. The `Brain` interface that Shell and Senses use does not change.

- **Request.** A request can carry several messages and a list of tools, not one question only.
- **Loop.** The Guide answers, or calls `search_map` or `read_project_memory` and then answers. At most 2 such calls per question, then it must answer (kept 14 November, tuned after the MVP test). While it searches no words arrive, so the card stays in its waiting state.
- **Sending back.** When the model calls the tool, its whole reply goes back unchanged together with the search result, including the model's hidden "thinking" blocks. The Claude API requires this: check its documentation when building. The first message, with the picture, is sent again unchanged. All of it is dropped when the answer is done.
- **Caching.** The system prompt, the tool definition and the profile are marked for caching. They are identical from call to call, and the profile text changes only when a fact in it changes. By the price table in the code, a cached part costs about a twentieth of the normal price. It lasts 5 minutes from the last call, the first call pays a quarter more on that part, and a part that is too short is not cached at all (about 512 tokens today: check the Claude API documentation for the current figure). Until caching is built (roadmap PS.4 at the latest) nothing is cached: layer 1 is paid in full on every call and a search pays for the picture twice.
- **Kept turns.** As in 5.8: text only, never an earlier look.
- **The "remember" route.** Today it answers "I can't remember things yet". It is replaced as written in 5.9.

All figures in 5.11 are estimates. None was measured.

5.12 onwards (storage, encryption, export) are in `05-map-storage.md`.
