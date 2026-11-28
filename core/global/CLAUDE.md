@AGENTS.md

# Claude Code

What Claude Code adds to the rules in `AGENTS.md`: its tools, the plugins and their skills.

- Use `offset` and `limit` to read only the sections of a file you need. Don't re-read whole files when you only need a few lines.

## Token-efficient workflow (plugins: superpowers, caveman, ponytail, graphify)
Goal: fewer rounds and less context read, not just shorter replies. These rules take precedence over plugin skills' defaults.

Where the project has its own workflow (`AGENTS.md`, "Process"), its steps replace superpowers' brainstorm, plan and execute chain. "Elsewhere" below means a project without one.

**One skill per step.** Several plugins offer a skill for the same step. Use the one in the "Use" column; the others run only when the user names them. `skillOverrides` can't hide them, since it doesn't reach plugin skills, so this table is what keeps them apart.

| Step | Use | Only when the user names it |
|---|---|---|
| Plan a branch | Plan mode and `docs/templates/spec.md`. Elsewhere: brainstorming, then writing-plans | feature-dev, `caveman:lean-build` |
| Build | Inline, from the approved plan; ponytail is always on. Elsewhere: executing-plans | subagent-driven-development, `caveman:surgical-patch`, `caveman:safe-refactor` |
| Tests first, for logic | test-driven-development | `engineering:testing-strategy` |
| Bug | systematic-debugging | `caveman:investigate-first`, `engineering:debug` |
| Look something up | Explore or `caveman:cavecrew-investigator` | `caveman:caveman-explore`, general-purpose |
| Verify before saying done | verification-before-completion | `caveman:verify-and-stop` |
| Review | The project's `code-reviewer` agent. Elsewhere: requesting-code-review | `ponytail:ponytail-review`, `caveman:caveman-review`, `caveman:cavecrew-reviewer`, `engineering:code-review`, `feature-dev:code-reviewer` |
| Finish a branch | The commit and push rule in `AGENTS.md` | finishing-a-development-branch, which offers to merge and push |

**Size the process to the task:**
- Small, clear change (1-2 files, obvious intent): no brainstorming, no plan file. Smallest change that works (ponytail), verify once.
- New feature or unclear ask: ask all clarifying questions in one batch. Agree the plan before code; don't reopen it mid-build. One review at the end, not one per task.
- Bugs: reproduce and find the root cause before editing; no guess-and-retry.
- Long work: keep progress in the plan's ledger or the project's notes so the user can /clear and say "continue". Keep the part read on resume short; history goes in a log.

**Model.** A session's model and effort are the user's settings. When the work is light (docs, templates, small changes with tests), say so and ask the user to switch to Sonnet 5.5 with `/model`; never switch on your own.

**Subagents** (keep each agent's default model; don't force one globally):
- Lookups ("where is X", "what calls Y"): `caveman:cavecrew-investigator` or Explore (both Haiku), when the answer needs a sweep across many files. A single grep or graphify query stays inline. Never general-purpose for lookups (it runs on Opus).
- A search that needs reading code rather than locating it (tracing a data flow, listing what breaks if X changes) may pass `model: sonnet` on that call.

**graphify:** where `graphify-out/` exists, ask the graph before grepping: `graphify query "<question>"`, `graphify explain "X"`, `graphify affected "X"` (Bash, no LLM cost). `graphify update .` refreshes it for free after code changes. A full build costs tokens: only when the user runs `/graphify`, never on small repos.

**Voice:** caveman is the terse voice for routine chat; `AGENTS.md` says where plain English stays.

# graphify
- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.
