# 9. Starting with Claude Code

## 9.1 What is in the project folder

```
Phew!/
  CLAUDE.md            rules every session reads
  roadmap.html         the checklist Claude Code ticks
  .claude/agents/      the five roles
  docs/                this plan
  Phew.xcodeproj       the Xcode project
  Phew/                the app: Shell, Senses, Brain, Map
  PhewTests/           unit tests
```

`.claude` is a hidden folder. In Finder press Command, Shift and full stop to see it.

## 9.2 The roles

Roles are Claude Code subagents: Markdown files in `.claude/agents/`. The main session is the lead. It plans, then hands work to a role by name.

| Role | Owns | Phases |
|---|---|---|
| lead | The main session. Plans, delegates, talks to you | All |
| shell | Menu bar, input panel, pointer overlay, text card | P1, P4 |
| senses | Accessibility reader, screen capture, speech, secrets filter | P2, P6 |
| brain | Claude API client, agents, prompts | P3 |
| map | SQLite, Librarian, course detection | P5 |
| checker | Builds, runs, verifies each task, ticks `roadmap.html` | End of every phase |

Builders run on Opus, the checker on Sonnet. This is set by the `model` line in each role file.

## 9.3 Starting a session

The project, git and signing are set up (done in P0). To work on it, open Terminal:

```
cd "path/to/Phew!"
claude
```

First message to Claude Code:

```
Read CLAUDE.md, roadmap.html and docs/06-sprint.md.
Tell me the current phase and its open tasks. Do not write code yet.
```

If Claude Code does not see the roles, quit and start `claude` again.

## 9.4 Every phase

Start:

```
Start phase P1. Read the docs listed for it in CLAUDE.md.
Plan the tasks, show me the plan, then use the shell subagent to build.
```

Finish:

```
Use the checker subagent to verify every task of P1 against its "done when".
Tick only what passes in roadmap.html, add a line to the log in docs/07-decisions.md, and commit.
```

Open `roadmap.html` in the browser and refresh to see progress.

## 9.5 Two terminals in parallel, optional

P1 with P2, and P4 with P5, do not touch the same files. To run two at once, give the second its own working copy:

```
git worktree add ../Phew-senses -b senses
cd ../Phew-senses
claude
```

When both are verified, ask the lead in the main folder to merge the branch. If this sounds like more trouble than it saves, run the phases one after the other.

## 9.6 The API key

In P3 Claude Code will ask for a Claude API key. Create it in the Claude Console and paste it only into the prompt Phew shows, which stores it in the Keychain. Never paste it into a file or into the chat with Claude Code.

## 9.7 Habits

- One phase per session. Start a fresh session for the next phase.
- If Claude Code proposes something outside the phase, say "parking list".
- When something breaks, describe what you saw. Do not suggest the fix.
- From P3, use Phew for your own coursework every day.

Documentation: https://code.claude.com/docs/en/sub-agents
