@AGENTS.md

# Claude Code

What Claude Code adds to the rules in `AGENTS.md`: its tools, the plugins and their skills.

- Use `offset` and `limit` to read only the sections of a file you need. Don't re-read whole files when you only need a few lines.

## Token-efficient workflow (plugins: superpowers, caveman, ponytail, graphify)
Goal: fewer rounds and less context read, not just shorter replies. These rules take precedence over plugin skills' defaults.

Where the project has its own workflow (`AGENTS.md`, "Process"), don't run superpowers' brainstorm/plan/execute chain alongside it.

**Elsewhere, size the process to the task:**
- Small, clear change (1-2 files, obvious intent): no brainstorming, no plan file. Smallest change that works (ponytail), verify once.
- New feature or unclear ask: superpowers brainstorming, with all clarifying questions in one batch, then writing-plans. Agree the plan before code; don't reopen it mid-build. Execute Native/inline (executing-plans), not subagent-driven, unless the user asks: one review at the end, not one per task.
- Bugs: systematic-debugging. Reproduce and find the root cause before editing; no guess-and-retry.
- Before saying done: verification-before-completion. Run the check; report only what ran.
- Long work: keep progress in the plan's ledger or the project's notes so the user can /clear and say "continue". Keep the part read on resume short; history goes in a log.

**Subagents** (keep each agent's default model; don't force one globally):
- Lookups ("where is X", "what calls Y"): `caveman:cavecrew-investigator` or Explore (both Haiku), when the answer needs a sweep across many files. A single grep or graphify query stays inline. Never general-purpose for lookups (it runs on Opus).
- A search that needs reading code rather than locating it (tracing a data flow, listing what breaks if X changes) may pass `model: sonnet` on that call.
- Review: where the project has no reviewer agent of its own, superpowers' requesting-code-review. Don't add caveman or ponytail reviews on top.

**graphify:** where `graphify-out/` exists, ask the graph before grepping: `graphify query "<question>"`, `graphify explain "X"`, `graphify affected "X"` (Bash, no LLM cost). `graphify update .` refreshes it for free after code changes. A full build costs tokens: only when the user runs `/graphify`, never on small repos.

**Voice:** caveman is the terse voice for routine chat; `AGENTS.md` says where plain English stays.

# graphify
- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.
