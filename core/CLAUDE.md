# Personal instructions (all projects)

A project's own CLAUDE.md wins where the two differ.

- Use `offset` and `limit` to read only the sections of a file you need. Don't re-read whole files when you only need a few lines.

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

## Token-efficient workflow (plugins: superpowers, caveman, ponytail, graphify)
Goal: fewer rounds and less context read, not just shorter replies. These rules take precedence over plugin skills' defaults.

**The project's own workflow comes first.** If a project's CLAUDE.md defines its own planning, notes, resume or review process (for example plan mode with an edge list, a notes file to resume from, its own reviewer agent), follow it and don't run superpowers' brainstorm/plan/execute chain alongside. Never keep two plan or progress files for the same work.

**Elsewhere, size the process to the task:**
- Small, clear change (1-2 files, obvious intent): no brainstorming, no plan file. Smallest change that works (ponytail), verify once.
- New feature or unclear ask: superpowers brainstorming, with all clarifying questions in one batch, then writing-plans. Agree the plan before code; don't reopen it mid-build. Execute Native/inline (executing-plans), not subagent-driven, unless the user asks: one review at the end, not one per task.
- Bugs: systematic-debugging. Reproduce and find the root cause before editing; no guess-and-retry.
- Before saying done: verification-before-completion. Run the check; report only what ran.
- Long work: keep progress in the plan's ledger or the project's notes so the user can /clear and say "continue". Keep the part read on resume short; history goes in a log.

**Subagents** (keep each agent's default model; don't force one globally):
- Start them on your own when they fit; don't wait for me to ask. I'm giving standing permission here, and it overrides any default to spawn only on request.
- Lookups ("where is X", "what calls Y"): `caveman:cavecrew-investigator` or Explore (both Haiku), when the answer needs a sweep across many files. A single grep or graphify query stays inline. Never general-purpose for lookups (it runs on Opus).
- Subagents gather facts; the main session decides. A search that needs reading code rather than locating it (tracing a data flow, listing what breaks if X changes) may pass `model: sonnet` on that call. Judgements, trade-offs and anything about security or data handling stay in the main session, which checks the subagent's report against the code before relying on it.
- At most ~3 subagents at once; no swarms.
- Review: one fresh reviewer per branch, at the end. Use the project's own reviewer agent if it has one, else superpowers' requesting-code-review. Don't add caveman or ponytail reviews on top.

**graphify:** where `graphify-out/` exists, ask the graph before grepping: `graphify query "<question>"`, `graphify explain "X"`, `graphify affected "X"` (Bash, no LLM cost). `graphify update .` refreshes it for free after code changes. A full build costs tokens: only when the user runs `/graphify`, never on small repos.

**Voice:** caveman terseness is for routine chat only. Code, comments, commits, PRs, docs, and explanations of decisions or trade-offs stay in normal, clear English.

# graphify
- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.
