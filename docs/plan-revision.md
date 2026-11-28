# Plan: revise agent-workflow

The only plan and ledger for this revision. Started 28 Nov 2026. Decisions made so far are in [decisions.md](decisions.md); every open one is marked **Open** below and is asked one at a time.

## Context

Facts checked on `main` (0ac0485), 28 Nov 2026:

- Everything is written for Claude Code. The project's root `CLAUDE.md` is only `@` imports, which no other tool follows.
- The README, `install.sh` and the tests still say `claude-workflow`. The repository is `inezamanda/agent-workflow`.
- `principles.md` relies on a design doc, a decisions log and an edge list, but there's no template for any of them.
- An iOS app built with this workflow has the applied version: a `pre-commit` hook, `commit-checks.py`, `check-folder-rules.py`, `ci-checks.sh`, `checks.yml`, `.swift-format` and `.swiftlint.yml`. The parts that hold for any project are lifted here. Its names, ids and app-only checks stay in that app.

Level: **light** (docs, templates and scripts; no user data). The hooks and `install.sh` are logic, so their tests are shown failing first. Effort: **XL**, so it's split into five branches.

## What each tool reads (docs read 28 Nov 2026)

| | Instructions | Skills | Subagents | Hooks | Permissions |
|---|---|---|---|---|---|
| Claude Code | `CLAUDE.md`; `AGENTS.md` only when there's no `CLAUDE.md` ([memory](https://code.claude.com/docs/en/memory)) | `.claude/skills/` ([skills](https://code.claude.com/docs/en/skills)) | `.claude/agents/*.md` ([sub-agents](https://code.claude.com/docs/en/sub-agents)) | `settings.json` ([hooks](https://code.claude.com/docs/en/hooks)) | `permissions` allow, ask, deny ([permissions](https://code.claude.com/docs/en/permissions)) |
| Codex | `AGENTS.md`, git root down to the working folder, 32 KiB in all by default ([agents-md](https://learn.chatgpt.com/docs/agent-configuration/agents-md)) | `.agents/skills/` ([skills](https://learn.chatgpt.com/codex/build-skills)) | `.codex/agents/*.toml` ([subagents](https://learn.chatgpt.com/codex/agent-configuration/subagents)) | `hooks.json` ([hooks](https://learn.chatgpt.com/codex/hooks)) | `config.toml` (not verified) |
| Cursor | `AGENTS.md`, nested too ([rules](https://cursor.com/docs/context/rules)) | `.agents/skills/`, `.claude/skills/` ([skills](https://cursor.com/docs/context/skills)) | `.cursor/agents/`, also `.claude/agents/` ([subagents](https://cursor.com/docs/context/subagents)) | `.cursor/hooks.json`, also Claude's ([hooks](https://cursor.com/docs/agent/hooks)) | not documented (pages 404) |
| Antigravity | `AGENTS.md`, `.agents/rules/` ([rules](https://antigravity.google/docs/rules)) | `.agents/skills/` ([skills](https://antigravity.google/docs/skills)) | `.agents/agents/*.md` ([subagents](https://antigravity.google/docs/subagents)) | `.agents/hooks.json` ([hooks](https://antigravity.google/docs/hooks)) | deny, ask, allow lists ([permissions](https://antigravity.google/docs/permissions)) |
| OpenCode | `AGENTS.md`, else `CLAUDE.md` ([rules](https://opencode.ai/docs/rules)) | `.agents/skills/`, `.claude/skills/` ([skills](https://opencode.ai/docs/skills)) | | | `opencode.jsonc` ([permissions](https://opencode.ai/docs/permissions)) |
| Augment | `AGENTS.md`, else `CLAUDE.md` ([rules](https://docs.augmentcode.com/cli/rules.md)) | `.agents/skills/`, `.claude/skills/` ([skills](https://docs.augmentcode.com/cli/skills.md)) | | `.augment/settings.json` ([hooks](https://docs.augmentcode.com/cli/hooks.md)) | same file ([permissions](https://docs.augmentcode.com/cli/permissions.md)) |

So `AGENTS.md` and `.agents/skills/` are shared by every tool but Claude, which gets a `CLAUDE.md` that imports `AGENTS.md` and a `.claude/skills` link. Subagents, hooks and permissions have no shared format: each tool gets its own small file, only once it's used (decisions, 28 Nov).

## Target layout

```
core/                          for any project, any tool
  global/AGENTS.md             rules for every session: vocabulary, commit OK, voice, sessions and subagents
  global/CLAUDE.md             Claude adapter: @AGENTS.md, then the plugins and one skill per step
  principles.md                kept; the changes are listed under commit 9
  AGENTS.md                    the project's root file: what to read, and where the notes live
  CLAUDE.md                    the project's Claude bridge: @AGENTS.md and the imports
  CONTRIBUTING.md
  templates/spec.md            a branch's plan: context, design review, edge list, tests, commits, ledger
  templates/decisions.md
  templates/edge-list.md
  agents/code-reviewer.md      the same body for every tool; Claude's frontmatter for now
  agents/test-writer.md        experiment
  agents/test-runner.md        experiment
  hooks/commit-msg             types and scopes read from CONTRIBUTING.md
  hooks/pre-commit             no commit on main, protected and private paths, commit size
  checks/ci-checks.sh          the hooks again, on each commit of a pull request
  github/checks.yml  github/review.yml  github/CODEOWNERS  github/pull_request_template.md
  claude/settings.json         Claude adapter: protected paths need the maintainer's OK
apple/
  CODING.md  code-smells.md    code-smells.md is today's apple/CLAUDE.md, renamed
  swift-format.json  swiftlint.yml
  hooks/pre-commit-swift       swift-format and SwiftLint on staged files
  github/checks-swift.yml      lint and package tests on Linux
docs/                          this repository's own plan and decisions, public
```

## Who does what

The maintainer orchestrates. A session may plan, write code, start subagents and check what they report. It must bring back to the maintainer: every real decision, every subagent finding it rejects (with why), anything that crosses a decision, and each commit for an OK. Sessions never message each other; they share through the maintainer, the notes and `main`.

| Role | Kind | Model, effort (proposed) | Input | Output | Tools | May not | When |
|---|---|---|---|---|---|---|---|
| Planner | session, plan mode in Claude | Opus 5.5 high; xhigh only when plan reviews keep finding design musts | the task, the code, the notes | the spec file, from the template | read, search | write code; decide for the maintainer | before each branch |
| Implementer | session | Opus 5.5 high on full level, Sonnet 5.5 high on light | the approved spec | commits, each shown before its OK | all, within the hooks | change the spec without stopping to ask | after the spec is approved |
| Explorer | subagent | Haiku 5.5, low | one question | `path:line` facts | read, search | judge or decide | when a lookup spans many files |
| Test writer | subagent, **experiment** | the implementer's model, so only independence changes | the spec's approved types, function names and test names | failing tests, never code | read; write only in test folders | read the implementation; change a test name | before each logic commit |
| Reviewer | subagent, fresh context | Opus 5.5: xhigh on full level, high on light | the spec, then the branch | findings by severity, `path:line` | read, the read-only commands | edit; see the maintainer's findings | the spec once, the branch once at its end |

The model and effort sit in each agent's own file (Claude's `model` and `effort` fields), never as one global setting. API list prices per million tokens, input/output, on 3 Nov 2026: Fable 5.2 $8/$40, Opus 5.5 $4/$20, Sonnet 5.5 $2/$10, Haiku 5.5 $0.10/$0.50. On a subscription they show the relative cost, not a bill. Fable isn't used: it draws on paid credit (decisions, 28 Nov). There's no test-runner agent: `test.sh` already summarizes, and a cheap model could report a failed run as passed; the session reads the script's own summary. Explorers' "not found" is checked with grep before it's believed. The experiment can also try Sonnet 5.5 as the implementer on a full-level branch.

Parallel work: one worktree, one session and one branch per independent task, each with its own reviewer at its end. Two tasks that need to talk aren't independent; they run one after the other. An Apple project gives each worktree its own simulator and derived data folder.

## Guardrails

What must hold goes where every tool hits it; a tool's own hooks and permissions are an extra layer that stops a mistake earlier.

1. **`pre-commit`** (every tool, on the maintainer's Mac): no commit on `main`; no private path where the notes are private; no path into private notes in public files; the scrub list; protected paths (below); a warning past 200 changed lines outside tests.
2. **`commit-msg`**: Conventional Commits, types and scopes from `CONTRIBUTING.md`, the AI credit rule.
3. **CI, `checks.yml`**: both hooks again on every commit of the pull request, so a skipped hook is still caught; then the linters.
4. **GitHub**: a ruleset on `main` (pull request required, no force-push) and `CODEOWNERS` on the protected paths.
5. **Claude, `claude/settings.json`**: `Edit(...)` rules on the protected paths, so Claude stops and asks.

Protected paths are listed once per project, for example the protocol folder, the data models, the lockfiles and the release config. A local hook can't stop an agent that runs the shell as the maintainer; it makes the change visible in the commit the maintainer approves, and CI and review enforce it.

- **Open:** how a commit says the maintainer approved a protected change (refuse, maintainer commits it themselves; a `Protected:` line in the message; or warn only).
- **Open:** one list read by the hook, CI and `CODEOWNERS`, or `CODEOWNERS` as the list.
- **Open:** a sole maintainer can't approve their own pull request, so `CODEOWNERS` review only helps with a second person or a bot account. Keep it?
- **Open:** Claude's rule is `ask` (it asks each time) or `deny` (it can't, and says so).

## Templates

- **spec.md**: context (facts checked, with the commit), level and effort; design review table (decision, chosen, rejected and why, who, a flag where the maintainer hasn't decided); a link to the edge list; test names per commit; commits with size estimates; proof; docs to update; ledger (approved commits, hashes, the maintainer's notes, the next commit).
- **decisions.md**: date, area, decision, why, who; then open questions (raised, question, where it stands).
- **edge-list.md**: per screen or function, one row per edge: empty, wrong or too long input; each picker option; errors and interruptions mid-action; keyboard, sheets, alerts and focus; screen readers, large text, dark mode; what other screens show afterwards. Columns: edge, expected, decision, test.
- **The spec catches what reviews kept finding.** In six past plan reviews of the iOS app, most findings were claims about existing code that were wrong, and tests that couldn't fail. So the spec template asks for a `path:line` behind every claim about existing code, and the mutation each test catches; and it ends with a "ready for review" checklist the planner runs first. The reviewer checks those, and spends its effort on design.
- **Review rounds, for the plan and for the branch alike:** round 1 reads everything. Round 2 reads its own findings, the diff since round 1, and the code and plan sections each fix touches or depends on: the iOS app's round-2 musts sat there, including fixes that showed the real problem was a different one. A full fresh re-read runs only on a full-level branch where a round-1 must changed the design, since that's where problems far from the fixes turned up (decisions, 28 Nov).
- **decisions.md** is append-only and has `docs/decisions.md merge=union` in the project's `.gitattributes`, so parallel branches' new rows merge without a conflict. Its header says to search by area and to archive past about 300 lines (decisions, 28 Nov). Not verified: whether GitHub's merge button uses the driver; if it shows a conflict, `git merge main` in the branch, locally, settles it.

## Commits

Sizes count non-test lines added and removed. Five branches, each a pull request, one after another: almost every one changes `install.sh` and its tests (decisions, 28 Nov). Each starts in a fresh session from this plan.

**Branch 1, `fix/repository-name`**

1. `docs: name the repository agent-workflow in the readme`: title, clone URL, curl URL. ~6 lines, S.
2. `feat: rename the command and its clone to agent-workflow`: `install.sh`, the README's command lines, the tests. ~40, S. An existing `~/.claude-workflow` clone is moved to `~/.agent-workflow` and its links are made again (decisions, 28 Nov). Renaming the clone's folder broke the `~/.claude/CLAUDE.md` link on 28 Nov, and sessions ran without the global rules until `install.sh` ran again. A warning inside `install.sh` wouldn't help, since a run already relinks, so the README says to run it after moving or renaming a clone. The commit also fixes two faults in the tests that a mutation showed: `check … [ a ] && [ b ]` checked only `a`, and two runs could clone from GitHub.
3. `docs: add the plan and the decisions log`: this file and `decisions.md`. ~190, M.

**Branch 2, `feat/agents-md`**

4. `docs: add templates for a spec, a decisions log and an edge list`: `install.sh project` copies them into `docs/templates/` and writes `.gitattributes` with the `union` line, which this repository gets too (decisions, 28 Nov). ~160, M.
5. `refactor: split the global instructions into AGENTS.md and a Claude adapter`: mostly a move; `install.sh` links the new path. ~60, S.
6. `feat: give projects an AGENTS.md that CLAUDE.md imports`: both templates; `install.sh` writes them and keeps its never-overwrite rule. ~100, M.
7. `feat: put the skills in .agents/skills with a .claude/skills link`: for skills a project keeps itself, such as the Axiom copies. ~40, S. Hudson's skills stay plugins (decisions, 28 Nov).
8. `docs: one skill per step in the Claude adapter`: the table (decisions, 28 Nov), replacing the duplicates; that `skillOverrides` doesn't reach plugin skills; and that a session doing light work asks the maintainer to switch to Sonnet 5.5. ~70, S.
9. `docs: make the principles tool-neutral and the notes a choice per project`: line 3, principle 2 (public or private notes), principle 8 (parallel sessions and worktrees), lines 91, 113 and 117. ~60, S.
10. `docs: let the reviewer read the spec first and the Swift skills`: `code-reviewer.md` reads `AGENTS.md` and the plan, checks the spec's citations and mutations, and has a round-2 mode that reads only its findings and the plan's diff. ~40, S.

**Branch 3, `feat/guardrails`**

11. `feat: read commit types and scopes from CONTRIBUTING.md`. ~50, S. **Open:** the checks stay `sh`, or move to `python3` like the iOS app's.
12. `feat: add a pre-commit hook for main, private paths and commit size`. ~110, M.
13. `feat: protect named paths in pre-commit, CODEOWNERS and Claude's settings`. ~100, M.
14. `ci: run the hooks on every commit of a pull request`: `ci-checks.sh`, `checks.yml`. ~90, M.

**Branch 4, `feat/apple-checks`**

15. `feat(apple): add swift-format and SwiftLint configs`: the iOS app's general rules, without its own. ~160, M.
16. `feat(apple): lint staged Swift files in pre-commit`. ~40, S.
17. `ci(apple): lint and run the package tests on Linux`. ~50, S.
17a. `feat(apple): add Axiom's accessibility and Instruments skills`: `accessibility-diag`, `ux-flow-audit`, `performance-profiling`, `memory-debugging`, `swiftui-performance`, copied into `.agents/skills/` at one pinned Axiom commit with its MIT notice, each read before it's added. A pure copy counts nothing; ~20 lines of notes. S. Checked first: each copied skill works without Axiom's routers and hooks. Axiom's Vision skills go to the iOS app later, not here. **Open:** drop `accessibility-diag`, now that Apple's plugin (17b) has VoiceOver, Dynamic Type and contrast skills, and whether `ux-flow-audit` stays.
17b. `feat(apple): install Apple's Xcode plugin with --apple`: `xcode@claude-plugins-official`, by Apple, added to the `--apple` plugin list, and its tests. ~10, S (decisions, 28 Nov). Its source is `xcrun agent plugin path --plugin-format claude`, so each Xcode release brings its own version: skills for accessibility, SwiftUI, App Intents, Swift Testing migration, devices and translation, and `xcrun mcpbridge` to Xcode's MCP tools (build, test, previews, simulators, documentation search). The tools work only while Xcode is open, and CI keeps `xcodebuild` and `swift test`. Checked first: its startup cost with `claude plugin details`, and whether Xcode must allow external agents in its Intelligence settings. Commit 8's table says which skill reviews SwiftUI, since `swiftui-specialist` overlaps `swiftui-pro`.

**Branch 5, `feat/agent-experiment`**

18. `feat: add the test-writer and test-runner agents`. ~100, M.
19. `docs: describe the experiment and its results table`. ~80, S.
20. `docs: describe the layout, the tools and the guardrails in the readme`. ~80, S.

Also open: whether this repository gets its own root `AGENTS.md` and `CLAUDE.md`, and whether graphify's `post-commit` refresh joins `core/`.

## Experiment

The question: does a test writer that works from the spec, before the code exists, give better tests and less rework for the tokens it costs?

- **Setup:** two small logic features in the iOS app, each with an approved spec, built twice from the same base commit in two worktrees. Run A is the current setup: the session writes tests and code, and one reviewer runs at the end. Run B adds the test writer and the test runner. The order is swapped for the second feature.
- **Record per run:** tokens (main session and subagents), time from approved spec to last commit, the maintainer's findings per commit, the reviewer's findings by severity, rework (fixup commits and the lines they change), and whether a test fails when the code is broken on purpose.
- **Decide beforehand:** what result keeps the test writer. **Open**, for the maintainer.
- **Limit:** four runs show a direction, not proof. The maintainer reviews the second run already knowing the code, so wait a day between runs.

## Ledger

| # | Commit | Hash | Maintainer's notes |
|---|---|---|---|
| 1 | `docs: name the repository agent-workflow in the readme` | 007851a | OK as proposed |
| 2 | `feat: rename the command and its clone to agent-workflow` | 338dd42 | Test fixes kept in the same commit |
| 3 | `docs: add the plan and the decisions log` | 5ff7ca6 | OK as proposed |
| 4 | `docs: add templates for a spec, a decisions log and an edge list` | 9511f6d | OK as proposed; templates go to `docs/templates/` on the agent's recommendation |
| 5 | `refactor: split the global instructions into AGENTS.md and a Claude adapter` | c40c180 | OK as proposed; `install.sh` run after it to relink `~/.claude` |

Branch 1 pushed as pull request #1, without a branch review (light level; maintainer, 28 Nov). Branch 2 starts on top of it, at light level: per the decisions of 28 Nov, its implementing session runs on Sonnet 5.5, high effort, started fresh. Next: commit 6, which also commits the notes changed since commit 5. Still open: decisions 2 to 5 and 9 (branch 3), 10 and 11, 12 (branch 5), and 17a's Axiom accessibility copy (branch 4).
