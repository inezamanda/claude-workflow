# agent-workflow

This is how I work with [Claude Code](https://claude.com/claude-code): the workflow I've found keeps my projects small, reviewable and safe. The agent writes the code; I decide, review every commit before it goes in, and understand each step. It's tuned for apps on Apple platforms, but most of it holds for any project.

## What's here

```
core/                              for any project
  global/AGENTS.md                 global instructions for every session, any tool
  global/CLAUDE.md                 Claude Code's part: imports AGENTS.md, then the plugins and skills
  project/AGENTS.md                a project's root instructions for any tool: what to read, where the notes are
  project/CLAUDE.md                a project's file for Claude Code: imports AGENTS.md and what it lists
  CLAUDE.md                        forwards to global/CLAUDE.md, for links made before the global files moved
  principles.md                    how work is planned, proven, reviewed and committed
  CONTRIBUTING.md                  commits, branches and pull requests (a template)
  agents/code-reviewer.md          a read-only reviewer for a whole branch
  github/review.yml                a Claude review of each pull request
  github/pull_request_template.md
  github/CODEOWNERS                the paths the hooks protect, the guards to start with
  github/checks.yml                the hooks again on every commit of a pull request
  checks/ci-checks.sh              what checks.yml runs
  claude/settings.json             Claude Code's hook block for a project
  claude/protected-edit.sh         asks before Claude edits a path CODEOWNERS lists
  templates/                       a branch's spec, a decisions log and an edge list
  skills/README.md                 how a project keeps its own skills, for every tool
  hooks/commit-msg                 Conventional Commits, AI credit allowed or refused, scrub
  hooks/pre-commit                 no commit on main, private paths, scrub, commit size
  hooks/checks.sh                  shared by both hooks
  hooks/scrub.sh                   the local scrub list check
apple/                             for Swift and SwiftUI apps, on top of core/
  CLAUDE.md                        a code-smell table for Swift
  CODING.md                        a coding guide (a template)
install.sh                         sets up a machine, and copies the templates into a project
scripts/                           this repository's own hooks, and the tests
```

Files marked as templates have `<placeholders>` and `<!-- notes -->` to fill in or delete.

## How to use it

**Once per machine**, a Mac or a Linux VM:

```sh
git clone https://github.com/inezamanda/agent-workflow.git ~/.agent-workflow
~/.agent-workflow/install.sh
```

Or without cloning first, which clones to `~/.agent-workflow` for you:

```sh
curl -fsSL https://raw.githubusercontent.com/inezamanda/agent-workflow/main/install.sh | sh
```

It links `~/.claude/CLAUDE.md` to `core/global/CLAUDE.md` (moving an old one to a dated backup), which imports `AGENTS.md` beside it, puts an `agent-workflow` command in `~/.local/bin`, and installs the plugins below. Each step is skipped when it's done, so it's safe to run again. Claude Code loads `~/.claude/CLAUDE.md` in every project, and a project's own `CLAUDE.md` wins where the two differ.

**In a new project**, at the root of its repository:

```sh
agent-workflow project             # any project
agent-workflow project --apple     # a Swift or SwiftUI app
```

| Command | Adds |
| --- | --- |
| `project` | `docs/principles.md`, `CONTRIBUTING.md`, `scripts/hooks/` (`commit-msg`, `pre-commit`, `checks.sh` and `scrub.sh`; a kept copy that differs from `core/hooks/` is warned about), `scripts/ci-checks.sh` and `.github/workflows/checks.yml`, which run them on every commit of a pull request (`checks.yml` only once the hooks know CI), `.claude/settings.json` and `.claude/hooks/protected-edit.sh`, which ask before Claude edits a protected path (a kept `settings.json` gets the block to add), `.claude/agents/code-reviewer.md`, `.github/workflows/review.yml`, `.github/pull_request_template.md`, `.github/CODEOWNERS` unless the project has one (then it prints the lines to add), the spec, decisions log and edge list templates in `docs/templates/`, a `.gitattributes` that merges `docs/decisions.md` with `union`, `.agents/skills/` for the project's own skills with a `.claude/skills` link to it, a root `AGENTS.md` that lists what to read, for any agent tool, and a root `CLAUDE.md` that imports `AGENTS.md` and the same files; it also sets `core.hooksPath` |
| `project --apple` | the same, plus `CODING.md` and `docs/code-smells.md`, the swift-lsp plugin and the three Swift skills |

It never overwrites a file that's already there. With `--apple` it leaves out `docs/code-smells.md` when a `CLAUDE.md` in a folder above already has the same text, since Claude Code loads that one too. If the project has an `AGENTS.md` or `CLAUDE.md` of its own, it prints the files or import lines to add instead; if it has a `.claude/skills` folder, it prints the command that links it. A project set up before the principles were renamed has them as `docs/CLAUDE.md`, so when that file is there it doesn't add `docs/principles.md`; it prints the `git mv` to run and the lines to change.

Where the notes are private, because `docs/` is git-ignored or a repository of its own, `AGENTS.md` and `CLAUDE.md` name private files, so it adds them to `.gitignore`, and it says how to untrack either one if it's already tracked. The `union` line then goes in `docs/.gitattributes`, beside the decisions log. Git-ignored files aren't checked out into a new worktree, so a worktree of such a project needs them brought in by hand. Then fill in the `<placeholders>`. `review.yml` needs a `CLAUDE_CODE_OAUTH_TOKEN` secret, made with `claude setup-token`.

`principles.md` describes two levels: **full**, for projects that hold people's data, money or credentials, and **light**, for everything else. Pick one in each plan.

## The plugins it installs

`core/global/CLAUDE.md` sets how these work together. Each is someone else's project.

- [superpowers](https://github.com/obra/superpowers): skills for brainstorming, planning, debugging and verifying.
- [caveman](https://github.com/JuliusBrussee/caveman): terse replies in routine chat.
- [ponytail](https://github.com/DietrichGebert/ponytail): the smallest change that solves the task.
- [graphify](https://github.com/Graphify-Labs/graphify): a code graph to ask before searching files. It needs [uv](https://docs.astral.sh/uv/); without it, the script skips graphify and says so.
- swift-lsp, with `--apple` only: Swift code navigation for Claude (definitions, references, types), from Xcode's `sourcekit-lsp`.
- [Swift Concurrency Pro](https://github.com/twostraws/Swift-Concurrency-Agent-Skill), [SwiftUI Pro](https://github.com/twostraws/SwiftUI-Agent-Skill) and [Swift Testing Pro](https://github.com/twostraws/Swift-Testing-Agent-Skill), with `--apple` only: review and writing rules for modern Swift, by Paul Hudson. A skill's text becomes instructions to Claude, so keep auto-update off for their marketplaces in `/plugin`, read what changed, then run `/plugin update`. A project's `CODING.md` wins where they differ.

Optional, not installed: [claude-obsidian](https://github.com/AgriciDaniel/claude-obsidian), if you keep project notes in an Obsidian vault.

Without the plugins, the principles and templates still work; drop the plugin section from `core/global/CLAUDE.md`.

## This repository's own hooks

```sh
git config core.hooksPath scripts/hooks
```

They refuse a commit whose changes or message contain a word from `.git/info/scrub-words`, one word or phrase per line. The list lives inside `.git`, so it's never committed, and the hooks refuse every commit until it exists. `scripts/test-hooks.sh` tests these hooks and those in `core/hooks/`, and `scripts/test-install.sh` tests `install.sh`.

## Updating

Run `agent-workflow`. It pulls the clone, which `~/.claude/CLAUDE.md` links to, and installs any plugin that's new. Whatever the clone has checked out is live: an edit, or another branch, reaches every session at once. For a bigger change, work in a separate `git worktree` and merge it when it's done. A clone from before the rename, at `~/.claude-workflow`, moves to `~/.agent-workflow` on its next run, and the old `claude-workflow` command goes. After moving or renaming a clone yourself, run its `install.sh` again: the links point into it, and nothing else notices that they broke.
