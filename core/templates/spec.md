# Spec: <branch name>

<!-- One spec per branch, kept with the project's notes. It's the branch's only plan and ledger: the maintainer approves it before any code, and a new session continues from it. -->

<What the branch does and why, in a paragraph.>

## Context

Facts checked on `<branch>` (<commit>), <date>. Every claim about existing code has a `path:line` behind it, so the reviewer can check it rather than trust it.

- <fact> (`<path:line>`)

Level: **<full or light>**, because <reason>. Effort: **<S, M, L or XL>**.

## Design review

<!-- The key decisions and their trade-offs. Who is "maintainer" or "agent"; mark each one the maintainer hasn't decided explicitly as **not decided**, and ask it before the branch starts. Decided rows also go in the decisions log. -->

| Decision | Chosen | Rejected, and why | Who |
|---|---|---|---|
| <decision> | <option> | <option>: <why not> | <who> |

## Edge list

<A link to this branch's edge list, approved by the maintainer. A pure refactor needs none: it proves itself with the same test names and counts.>

## Tests

<!-- Proposed by the agent, approved by the maintainer before any code. The mutation is the change to the code that makes the test fail: a skipped save, an ignored argument, a flipped condition. A test with no mutation can't fail, so it proves nothing. -->

| Commit | Test | Mutation it catches |
|---|---|---|
| <#> | `<test name>` | <mutation> |

## Commits

Sizes count non-test lines added and removed, about 200 at most per commit; a pure move counts nothing.

1. `<type(scope): message>`: <what it changes>. ~<lines>, <S, M, L or XL>.

## Proof

<How the branch shows it works: which tests run where, device runs, screenshots, what the maintainer checks by hand.>

## Docs to update

<The README, the coding guide, the principles, the decisions log: whichever the change affects.>

## Ready for review

The planner checks each line before asking for a review; the reviewer checks them again and spends the rest of its effort on the design.

- [ ] Every claim about existing code has a `path:line`, read at the commit named in Context.
- [ ] Every test names the mutation it catches.
- [ ] Every decision names who made it, and none is still **not decided**.
- [ ] The edge list is approved, or the branch is a pure refactor.
- [ ] Every commit has a size, and none is over about 200 lines.
- [ ] The docs to update are listed.

## Ledger

| # | Commit | Hash | Maintainer's notes |
|---|---|---|---|
| | | | |

Next: <the next commit, so a new session can start from here>.
