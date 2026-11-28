# Decisions log

Choices made for this repository, newest at the bottom of the table. The plan for the current work is [plan-revision.md](plan-revision.md).

| Date | Area | Decision | Why | Who |
| --- | --- | --- | --- | --- |
| 2026-11-28 | Tools | Claude Code is the only agent in use. Cursor is used as an editor and terminal, not as an agent. | That's how the maintainer works today. | maintainer |
| 2026-11-28 | Tools | Shared logic now, config for Claude only. Each other tool gets its own small files in one commit, once it's really used. | Other tools (Codex, Cursor, Antigravity, OpenCode, Augment) may be tried later. Config for a tool nobody runs can't be tested and breaks quietly when its format changes. | maintainer |
| 2026-11-28 | Agents | The maintainer orchestrates. Planning and implementing are sessions, handed over through an approved plan file; the reviewer and explorers are subagents. A test writer and a test runner are tried as an experiment first. | Sessions can ask the maintainer; subagents can't. A role agent that plans or implements loses the context that the plan file carries. | maintainer |
| 2026-11-28 | Agents | Several sessions at once are supported, one worktree and one branch per independent task. | Tasks are often independent, and parallel sessions save time. | maintainer |
| 2026-11-28 | Notes | This repository's plans and decisions are public, in `docs/`. In the principles, public or private notes become a choice each project makes. | Here they hold nothing private, every worktree gets them, and the pull request review can read them. Projects with business plans or private details keep a private notes repository. | maintainer |
| 2026-11-28 | Install | When the command is renamed, an existing `~/.claude-workflow` clone is moved to `~/.agent-workflow`, and its links are made again. | One name on every machine; `install.sh` already backs up and relinks. | maintainer |
| 2026-11-28 | Agents | No role uses Fable. | On the maintainer's plan, Fable draws on paid usage credit, not the subscription. | maintainer |
| 2026-11-28 | Agents | Models: planner Opus 5.5 (xhigh full level, high light); implementer Opus 5.5 high (full) or Sonnet 5.5 high (light); reviewer Opus 5.5 (xhigh full, high light); explorer Haiku 5.5 low; test writer as the implementer; no test-runner agent. | Mistakes that reach the maintainer cost their review time, so those roles aren't cheapened; lookups are. A runner adds cost to a script that already summarizes. | maintainer |
| 2026-11-28 | Skills | Copy only Axiom's accessibility and Instruments skills into `apple/`, pinned and read first; not the whole plugin. Its Vision skills go to the iOS app later. | Hudson's packs don't cover these. The whole plugin brings 44 agents and hooks on every prompt, which go against the roles agreed here. | maintainer |
| 2026-11-28 | Review | Round 1 reads everything. Round 2 reads its findings, the diff and what each fix touches or depends on. A full fresh re-read only on a full-level branch where a round-1 must changed the design. Same for plan and branch reviews. | In the iOS app's notes, round-2 musts sat in or next to the fixes, sometimes showing the real problem was different; the one full re-read found problems elsewhere. Round 2 usually finds little, so a full re-read each time costs more than it finds. | maintainer |

## Open questions

| Raised | Question | Where things stand |
| --- | --- | --- |
| 2026-11-28 | Sessions never message each other; they share through the maintainer, the notes and `main`. | Proposed, not yet confirmed. |
| 2026-11-28 | One skill per step, and the duplicate review and planning skills left out. | Proposed in chat, not yet approved. |
