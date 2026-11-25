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
  hooks/commit-msg                 Conventional Commits, no AI attribution
apple/                             for Swift and SwiftUI apps, on top of core/
  CLAUDE.md                        a code-smell table for Swift
  CODING.md                        a coding guide (a template)
scripts/                           this repository's own hooks and their tests
```

Files marked as templates have `<placeholders>` and `<!-- notes -->` to fill in or delete.

## How to use it

**Every session.** Copy `core/CLAUDE.md` to `~/.claude/CLAUDE.md`. Claude Code loads it in every project, and a project's own `CLAUDE.md` wins where the two differ.

**Every Apple project.** Copy `apple/CLAUDE.md` into the folder that holds those projects, such as `~/Developer/iOS/CLAUDE.md`. Claude Code also loads the `CLAUDE.md` files of the folders above the project it opens, so it reaches each project in that folder and none outside it.

**A new project.** Copy what fits and fill in the placeholders:

| From | To |
| --- | --- |
| `core/principles.md` | `docs/CLAUDE.md`, imported from the root `CLAUDE.md` with `@docs/CLAUDE.md` |
| `core/CONTRIBUTING.md`, `apple/CODING.md` | the root, both imported from `CLAUDE.md` too |
| `core/agents/code-reviewer.md` | `.claude/agents/` |
| `core/github/review.yml` | `.github/workflows/` (it needs a `CLAUDE_CODE_OAUTH_TOKEN` secret, from `claude setup-token`) |
| `core/github/pull_request_template.md` | `.github/` |
| `core/hooks/commit-msg` | `scripts/hooks/`, then `git config core.hooksPath scripts/hooks` |

`principles.md` describes two levels: **full**, for projects that hold people's data, money or credentials, and **light**, for everything else. Pick one in each plan.

## The plugins it assumes

`core/CLAUDE.md` sets how these work together. Each is someone else's project; install it as its README says.

- [superpowers](https://github.com/obra/superpowers): skills for brainstorming, planning, debugging and verifying.
- [caveman](https://github.com/JuliusBrussee/caveman): terse replies in routine chat.
- [ponytail](https://github.com/DietrichGebert/ponytail): the smallest change that solves the task.
- [graphify](https://github.com/Graphify-Labs/graphify): a code graph to ask before searching files.

Without them, the principles and templates still work; drop the plugin section from `core/CLAUDE.md`.

## This repository's own hooks

```sh
git config core.hooksPath scripts/hooks
```

They refuse a commit whose changes or message contain a word from `.git/info/scrub-words`, one word or phrase per line. The list lives inside `.git`, so it's never committed, and the hooks refuse every commit until it exists. `scripts/test-hooks.sh` tests these hooks and `core/hooks/commit-msg`.

## Updating

Edit the files here, then copy `core/CLAUDE.md` to `~/.claude/CLAUDE.md` again. A copy, not a link, so a change reaches every session only when it's meant to.
