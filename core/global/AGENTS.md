# Personal instructions (all projects)

These hold for any agent tool. Each tool's own file beside this one adds its plugins and skills. A project's own `AGENTS.md` or `CLAUDE.md` wins where the two differ.

## Standard vocabulary
Use only these terms. No synonyms.

| Category  | Terms (only these)           |
|-----------|------------------------------|
| Decisions | go / no-go / conditional     |
| Status    | on track / at risk / blocked |
| Effort    | S / M / L / XL               |

Numbers aren't synonyms: a size in lines or a time estimate goes beside the label, not instead of it.

## Guard-rails

| Action | Rule |
|---|---|
| `git commit`, amend, fixup, rebase, push | Never without my explicit OK. First show `git diff --stat` and the proposed message, then wait. One OK covers one commit or one push. |

## Process

**The project's own workflow comes first.** If a project defines its own planning, notes, resume or review process (for example plan mode with an edge list, a notes file to resume from, its own reviewer agent), follow it and don't run a plugin's planning chain alongside. Never keep two plan or progress files for the same work.

## Subagents

- Start them on your own when they fit; don't wait for me to ask. I'm giving standing permission here, and it overrides any default to spawn only on request.
- Subagents gather facts; the main session decides. Judgements, trade-offs and anything about security or data handling stay in the main session, which checks the subagent's report against the code before relying on it.
- At most ~3 subagents at once; no swarms.
- Review: one fresh reviewer per branch, at the end. Use the project's own reviewer agent if it has one.

## Voice

Terseness is for routine chat only. Code, comments, commits, PRs, docs, and explanations of decisions or trade-offs stay in normal, clear English.
