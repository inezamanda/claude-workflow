#!/bin/sh
# Runs the hooks on every commit of a pull request but its merges, so a commit made with --no-verify, or in a clone
# without the hooks, is still checked. Each commit is checked in full: its changes, and its message as stored.
# The hooks and CODEOWNERS come from the base, so no commit can switch off its own check. A base whose hooks were
# set up before CI (they don't know CHECK_COMMIT) has the head's used instead, with a notice, so the pull request that
# upgrades them can pass.
# Usage: scripts/ci-checks.sh <base> <head>, in a clone that has both commits. Install it as scripts/ci-checks.sh.

[ $# -eq 2 ] || { echo "usage: ci-checks.sh <base> <head>" >&2; exit 2; }
base="$(git rev-parse --verify -q "$1^{commit}")" && head="$(git rev-parse --verify -q "$2^{commit}")" ||
    { echo "ci-checks: $1 or $2 isn't a commit in this clone" >&2; exit 2; }
cd "$(git rev-parse --show-toplevel)" && tmp="$(mktemp -d)" || exit 2
trap 'rm -rf "$tmp"' EXIT

# hooks <commit>: its scripts/hooks/commit-msg, pre-commit and checks.sh, copied to $tmp/<commit>; fails unless
# all three are there and know CHECK_COMMIT.
hooks() {
    mkdir -p "$tmp/$1" || return 1
    for f in commit-msg pre-commit checks.sh; do
        git cat-file blob "$1:scripts/hooks/$f" > "$tmp/$1/$f" 2>/dev/null && grep -q CHECK_COMMIT "$tmp/$1/$f" || return 1
    done
}
if hooks "$base"; then
    dir="$tmp/$base"
elif hooks "$head"; then
    dir="$tmp/$head"
    echo "ci-checks: the base's scripts/hooks don't check commits in CI yet, so the head's are used" >&2
else
    echo "ci-checks: neither the base nor the head has a scripts/hooks with commit-msg, pre-commit and checks.sh that know CHECK_COMMIT; copy them from agent-workflow's core/hooks" >&2
    exit 1
fi

# Each line a hook prints starts with the commit's short hash.
fail=0 count=0
for c in $(git rev-list --reverse --no-merges "$base..$head"); do
    count=$((count + 1)) short="$(git rev-parse --short "$c")"
    git log -1 --format=%B "$c" > "$tmp/msg" || exit 2
    for hook in pre-commit commit-msg; do
        out="$(CHECK_COMMIT="$c" CHECK_BASE="$base" ${SH:-sh} "$dir/$hook" "$tmp/msg" 2>&1 >/dev/null)" || fail=1
        [ -z "$out" ] || printf '%s\n' "$out" | sed "s/^/$short /" >&2
    done
done
echo "ci-checks: $count commits checked from $(git rev-parse --short "$base") to $(git rev-parse --short "$head")" >&2
exit $fail
