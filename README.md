# claude-workflow

This is how I work with [Claude Code](https://claude.com/claude-code): the workflow I've found keeps my projects small, reviewable and safe. The agent writes the code; I decide, review every commit before it goes in, and understand each step. It's tuned for apps on Apple platforms, but most of it holds for any project.

## What's here

```
core/                              for any project
  CLAUDE.md                        global instructions for every session
  principles.md                    how work is planned, proven, reviewed and committed
  CONTRIBUTING.md                  commits, branches and pull requests (a template)
  agents/code-reviewer.md          a read-only reviewer for a whole branch
  github/review.yml                a Claude review of each pull request
  github/pull_request_template.md
  hooks/commit-msg                 Conventional Commits, AI credit allowed or refused
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
git clone https://github.com/inezamanda/claude-workflow.git ~/.claude-workflow
~/.claude-workflow/install.sh
```

Or without cloning first, which clones to `~/.claude-workflow` for you:

```sh
curl -fsSL https://raw.githubusercontent.com/inezamanda/claude-workflow/main/install.sh | sh
```

It links `~/.claude/CLAUDE.md` to `core/CLAUDE.md` (moving an old one to a dated backup), puts a `claude-workflow` command in `~/.local/bin`, and installs the plugins below. Each step is skipped when it's done, so it's safe to run again. Claude Code loads `~/.claude/CLAUDE.md` in every project, and a project's own `CLAUDE.md` wins where the two differ.

**In a new project**, at the root of its repository:

```sh
claude-workflow project            # any project
claude-workflow project --apple    # a Swift or SwiftUI app
```

| Command | Adds |
| --- | --- |
| `project` | `docs/CLAUDE.md` (the principles), `CONTRIBUTING.md`, `scripts/hooks/commit-msg`, `.claude/agents/code-reviewer.md`, `.github/workflows/review.yml`, `.github/pull_request_template.md`, and a root `CLAUDE.md` that imports them; it also sets `core.hooksPath` |
| `project --apple` | the same, plus `CODING.md` and `docs/code-smells.md`, the swift-lsp plugin and the three Swift skills |

It never overwrites a file that's already there. With `--apple` it leaves out `docs/code-smells.md` when a `CLAUDE.md` in a folder above already has the same text, since Claude Code loads that one too. If the project has a `CLAUDE.md` of its own, it prints the import lines to add instead. Then fill in the `<placeholders>`. `review.yml` needs a `CLAUDE_CODE_OAUTH_TOKEN` secret, made with `claude setup-token`.

`principles.md` describes two levels: **full**, for projects that hold people's data, money or credentials, and **light**, for everything else. Pick one in each plan.

## The plugins it installs

`core/CLAUDE.md` sets how these work together. Each is someone else's project.

- [superpowers](https://github.com/obra/superpowers): skills for brainstorming, planning, debugging and verifying.
- [caveman](https://github.com/JuliusBrussee/caveman): terse replies in routine chat.
- [ponytail](https://github.com/DietrichGebert/ponytail): the smallest change that solves the task.
- [graphify](https://github.com/Graphify-Labs/graphify): a code graph to ask before searching files. It needs [uv](https://docs.astral.sh/uv/); without it, the script skips graphify and says so.
- swift-lsp, with `--apple` only: Swift code navigation for Claude (definitions, references, types), from Xcode's `sourcekit-lsp`.
- [Swift Concurrency Pro](https://github.com/twostraws/Swift-Concurrency-Agent-Skill), [SwiftUI Pro](https://github.com/twostraws/SwiftUI-Agent-Skill) and [Swift Testing Pro](https://github.com/twostraws/Swift-Testing-Agent-Skill), with `--apple` only: review and writing rules for modern Swift, by Paul Hudson. A skill's text becomes instructions to Claude, so keep auto-update off for their marketplaces in `/plugin`, read what changed, then run `/plugin update`. A project's `CODING.md` wins where they differ.

Optional, not installed: [claude-obsidian](https://github.com/AgriciDaniel/claude-obsidian), if you keep project notes in an Obsidian vault.

Without the plugins, the principles and templates still work; drop the plugin section from `core/CLAUDE.md`.

## This repository's own hooks

```sh
git config core.hooksPath scripts/hooks
```

They refuse a commit whose changes or message contain a word from `.git/info/scrub-words`, one word or phrase per line. The list lives inside `.git`, so it's never committed, and the hooks refuse every commit until it exists. `scripts/test-hooks.sh` tests these hooks and `core/hooks/commit-msg`, and `scripts/test-install.sh` tests `install.sh`.

## Updating

Run `claude-workflow`. It pulls the clone, which `~/.claude/CLAUDE.md` links to, and installs any plugin that's new. Whatever the clone has checked out is live: an edit, or another branch, reaches every session at once. For a bigger change, work in a separate `git worktree` and merge it when it's done.
