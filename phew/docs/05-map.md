# 5. The Map

Phew's understanding of meaning, connections and relationships. A light ontology with a small semantic layer on top, taken from your study and cut to what one student needs.

## 5.1 What was taken from your study, and what was left

| Taken | Left out |
|---|---|
| Start from competency questions | OWL, RDF, SPARQL, SHACL |
| Model 5 to 10 core classes | Formal reasoning engines |
| Reuse existing vocabularies before inventing | Warehouse tools: dbt, Cube, LookML |
| Property graph instead of formal logic | Modelling everything up front |
| Define each metric exactly once | Enterprise governance |
| Grow one use case at a time | |

Your study is sound for this purpose. Two notes: I did not verify its dates, and the Gartner figure of 80% accuracy gain is a forecast, not a measurement.

## 5.2 Competency questions

The Map exists to answer these. If a class or link does not help answer one, it is not added.

1. What is this on my screen, in terms of my course?
2. What have I not understood yet in this course?
3. Where did the lecturer explain this?
4. What is due this week, and what does it need?
5. What did I do last time on this project?
6. What should I do next?

## 5.3 Classes

Nine classes. Names follow schema.org where one exists.

| Class | Meaning | Example |
|---|---|---|
| Course | A subject the student follows | Typography 2 |
| Project | Own work with a goal | Thesis, startup |
| Assignment | Something to deliver | Poster brief |
| Concept | An idea to understand | Kerning |
| Source | Where knowledge sits | Slide deck, PDF, web page, lecture |
| Lecture | A captured lesson. A kind of Source | Lesson of 12 November |
| Person | Lecturer, teammate | |
| Session | A stretch of work Phew observed | 40 minutes in Figma |
| App | A tool in use | Figma, Keynote |

## 5.4 Links

| Link | From, to |
|---|---|
| part of | Assignment to Course, Lecture to Course |
| covers | Source to Concept |
| requires | Assignment to Concept, Concept to Concept |
| due on | Assignment to a date |
| worked on | Session to Project or Assignment |
| used | Session to App |
| understood, struggled with | Student to Concept, with a strength from 0 to 1 |
| taught by | Course to Person |

Every link stores where it came from, when, and how sure Phew is. This is what lets the student correct him and lets the Keeper clean up.

## 5.5 Small semantic layer: definitions written once

| Term | Definition |
|---|---|
| Due soon | Assignment with a due date within 7 days |
| Untouched | Assignment with no Session in the last 5 days |
| Weak concept | Concept with struggle strength above 0.6 and no later success |
| Covered | Concept linked to at least one Lecture or Source of the course |
| Next step | The first required Concept or Assignment that is weak or untouched, ordered by due date |

Agents use these terms. None of them invents its own meaning for "due soon".

## 5.6 Rules, not reasoning

Three simple rules instead of an inference engine.

- If an Assignment requires a Concept and the Concept is weak, the Guide starts from that Concept.
- If a Concept on screen is covered by a Lecture, the Guide points to that moment of the Lecture.
- If an Assignment is due soon and untouched, it becomes the answer to "what next". It is never pushed as a popup.

## 5.7 Three memories

| Memory | Holds | Lives |
|---|---|---|
| Working | The current task and the last few steps | On the Mac, minutes |
| Episodic | Events: what happened, when, in which app | Events table, months |
| Semantic | The Map: classes and links | Graph tables, permanent |

## 5.8 How it is filled

1. After each interaction the Librarian receives the context packet and the answer.
2. A small model extracts items and links, restricted to the classes and links above.
3. Each item is matched to an existing one or created. In the MVP the small model matches against the names already stored for that course. Embeddings come with the backend.
4. Links are added with source, time and confidence. Repeated evidence raises confidence.
5. Later, the Keeper merges duplicates at night, lowers stale confidence and recomputes the terms in 5.5.

## 5.9 Storage

Four tables. SQLite on the Mac in the MVP, Postgres with the same shape when the backend arrives. The embedding columns stay empty until then.

| Table | Columns |
|---|---|
| `nodes` | id, user, class, name, properties, embedding, created, updated |
| `edges` | id, user, from, to, link, strength, confidence, source event, created |
| `events` | id, user, time, app, kind, summary, embedding |
| `terms` | name, definition as a query |

## 5.10 How it grows

MVP: Course, Project, Concept, Source, Session and the links between them, enough for questions 1, 2 and 5. Assignment and due dates next. Lecture when lecture capture works. One use case at a time.

Until the dashboard exists, the Map can be exported to one readable Markdown file. That is the Transparent value in the MVP.
