# Contributing to <project>

<!-- One or two sentences: what the project is, and what a mistake costs the people who use it. The higher the stakes, the stricter the rules below. -->

## Setup

Install the hooks once per clone:

```sh
git config core.hooksPath scripts/hooks
```

Before every commit, the hooks refuse:

- a message that isn't `type(scope): subject` with a type and scope listed under Commits, runs past 100 characters, or credits an AI where the project doesn't allow it;
- a commit on `main`;
- a word from the scrub list in the message or the staged changes. The list is `.git/info/scrub-words`, one word or phrase per line, such as real names; it stays in `.git`, so it's never committed, and the hooks refuse every commit until it exists;
- where the notes are private, a commit that adds the notes, or a line or message that points into them;
- a change to a path `CODEOWNERS` lists, unless the message has a line `Protected: <why>`;
- <!-- each check the project's hooks add, one line each -->

They warn when a commit changes more than 200 lines outside tests. To fix up a protected change, use `git commit --fixup=amend:<commit>` or `--squash=<commit>` and keep the `Protected:` line: an autosquash drops a plain fixup's message, line included, and CI then fails.

Never skip them with `--no-verify`; if one is wrong, fix the check.

## Privacy

- Never use real people's data in code, tests, fixtures, logs or issues. Test values are made up and can't belong to anyone.
- Don't log field values, names, keys or file contents.
- <!-- The dependency policy, for example: open an issue before adding a dependency. -->

## Code

How code is written here (structure, naming, patterns, tests, style and comments) is in [CODING.md](CODING.md). Read it before your first pull request.

## Commits

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org): `type(scope): subject`, for example `fix(sync): keep the draft when the upload fails`.

- **Types:** `feat` (something new for the user), `fix` (a bug), `test` (tests only), `refactor` (no change in behaviour), `perf`, `docs`, `style` (formatting), `build`, `ci`, `chore`.
- **Scopes:** <!-- one per part of the project, in backticks, with what it covers. scripts/hooks/commit-msg reads the names in backticks on this line and the Types line; once a scope is listed here, only listed scopes pass. -->. Leave the scope out when a change spans several.
- **Subject:** imperative and lowercase, no full stop. Aim for 72 characters; the hook warns past that and refuses past 100.
- **Body:** say why, when it isn't obvious. Break lines only where you mean a break, like a new paragraph or a separate point. Don't break inside a sentence to keep lines short: GitHub keeps those breaks, and the text turns choppy.
- **AI credit:** <!-- Say whether commits credit the agent. If they don't, set ALLOW_AI_CREDIT=0 in scripts/hooks/commit-msg. -->
- **Breaking changes** get a `!` after the type and a `BREAKING CHANGE:` footer. <!-- Name what counts here: a stored format, a public API, a settings key. -->

Keep moves and reformatting in their own commits, separate from changes in behaviour, so each diff is easy to review.

## Branches and pull requests

Don't commit to `main`. Each piece of work gets its own branch, named `type/scope-topic` with the same types and scopes as commits, like `feat/sync-retry` or `fix/editor-draft`. Keep the small commits on that branch, then open a pull request into `main` that says what changed and which tests you ran; GitHub fills its description from `.github/pull_request_template.md`.

`.github/workflows/checks.yml` runs the hooks again on every commit of each pull request, merges aside, with the base's copies of the hooks and of `CODEOWNERS`, so no commit can switch off its own check. A commit that drops a path from `CODEOWNERS` and a later one in the same pull request that changes it without a `Protected:` line pass locally, but fail there. Protect `main` with a ruleset (Settings, Rules, Rulesets): require a pull request, block force pushes, and require the status check `checks`, so a red run blocks the merge.

What the checks can't catch:

- `--no-verify`, or a commit from a clone without the hooks: only CI catches it;
- a pull request that changes `checks.yml` itself, which runs as the pull request has it;
- a protected change made while resolving a merge conflict;
- an edit made from the shell rather than Claude's Edit tool: nothing asks first, though the commit still needs its `Protected:` line;
- a pull request whose base has no hooks, or older ones, is checked with its own, and one whose base has no `CODEOWNERS` protects nothing;
- git matches `CODEOWNERS` patterns more widely than GitHub: `a/*` also covers `a/b/c`, and a line without an owner still protects its paths.

<!-- What else runs on each pull request: the tests, the review. -->

Merge with **Create a merge commit**. Don't squash or rebase: notes and reviews refer to commits by their hash, and both of those create new hashes.
