# 5. The Map

Phew's memory of your work: what you are working on, with whom, with what, what was decided, and what you asked him before. It lives in two encrypted files on your Mac. They are never uploaded or synced. The few facts an answer needs are sent to the model together with your question.

Rewritten on 13 November 2026 for a general user. The first version was built around one student (Course, Assignment, Concept, Lecture). The research behind this version is in `10-research.md` 10.3 and 10.5. Completed on 14 November 2026 after the review of phase PR: the design is the same, and the points a builder would have had to guess are now written down.

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

The seventh link, "at", was added with the Event and Place classes so that a Place can be connected. "Document to Event" was added to "part of" on 14 November, so that slides can be tied to their lecture. Both approved on 14 November. Links whose meaning changes with the matter or the setting are an idea for after the MVP (5.14).

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
- **Wiped, not only hidden.** At the real delete the words are overwritten in the Map's file and taken out of the search indexes. See 5.12.
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

Sensitive things seen on screen (health, money, other people's private messages) are written like any other fact, and marked sensitive by the Librarian. Your decision of 14 November. A sensitive fact gets a second lock on top of the encryption of the whole Map (5.12), and is left out of the export unless you tick it. Marking rests on the Librarian's judgement, so it is tested in P5.2. How the lock works is decided after the P5 research task.

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

"Undo last import" in the menu removes every fact that came from the last import, at once, like a forget: the card names what went, and it waits 30 days in Recently deleted. A thing the import created is kept if something you told him or he observed now points to it. The real delete is wiped from the file like a forget (5.12). Last import only in version 1. Approved 14 November.

### Not in version 1

Reading the export files of ChatGPT, Claude or Gemini: no export has a documented format.

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

## 5.12 Storage

Two SQLite files on the Mac, in `~/Library/Application Support/Phew/`, beside `calls.log`: `map.sqlite` and `map-sensitive.sqlite`. Unit tests open a database in memory or in a temporary folder, never these files. Four tables, as before, with new columns, and a fifth, `forgets`, for Recently deleted. The same shape can move to Postgres when the backend arrives. That move would change the rule "The Map lives only on the Mac" and needs your decision first. Your own Time Machine backup, if you use one, copies these files like any other. Your decision of 14 November: they stay in backups.

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
- `properties` holds the few values special to a class, as JSON: a Task's `due` and `done`, an Event's `start` and `end`, a Document's `path` or `address`. Each value is stored with the origin that set it, which is what lets Priority be judged value by value (5.5).
- `aliases` holds other names for the same thing, including the name in another language, as a JSON list.
- `updated` is "last seen". `valid_from` and `valid_to` are "true from" and "true until". `superseded_by` is "replaced by".
- A history row (5.5) is a row in `nodes` with `valid_to` set and `superseded_by` pointing at the living row.
- `strength` is used only by "understands".
- Event kinds: ask, guide, tell, correction, task, import. A forget writes none.
- `mentions` is the list of ids of the things and Notes the past question mentions, stored as a JSON list. `project` is the id of its Project, or empty.
- `terms` holds each defined term of 5.6 once: its name and the query that computes it, with its numbers. It is filled when the Map is created. Tuning a number is one row changed. "Next step" is the exception: code runs the other queries in the order 5.6 gives.
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
- Results come back best match first (SQLite's own ranking), and a match in a name counts more than a match in a sentence. They are cut to the numbers in 5.11. Only current facts are returned, unless the past is asked for.
- If no words are left, the search is skipped. If the search fails for any reason, it returns nothing and the answer goes on without it. The failure is logged without the words of the question.
- The name matching of 5.9 uses the same index to find things with that name, then Phew's code compares the whole name. SQLite's own comparison does not ignore accents.
- Unit tests for P5.1 must include: a full sentence, a file name with a dot and a dash, a window title with a colon, a word with an apostrophe, an accented Italian word typed without the accent, and an empty question.

### Deleting for real

At the real delete after a forget or an undone import (after 30 days, or on Delete now), the deleted words leave the file, not only the tables:

- the database runs with `PRAGMA secure_delete = ON`;
- both text-search indexes have the FTS5 `secure-delete` option set to 1;
- there is no write-ahead file to empty, because the Map uses the rollback journal.

This needs SQLite 3.42 or later, and P5.1 checks the version. Tried on 14 November on a throwaway database with this Mac's SQLite 3.54: after these three steps a made-up name was no longer in the file. A unit test must repeat this: forget a made-up name, then look for it in the database file and its journal as raw text, on an unlocked test file (see "Encryption: the design").

### Encryption: the design

Approved by you on 14 November, after the research task P5.13. The research behind it is in `10-research.md` 10.7.

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
19. PhewTests runs inside Phew.app: add the SQLCipher product to PhewTests so `import SQLCipher` compiles there, linked but not embedded, and run `otool -L` on the test bundle too.
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
