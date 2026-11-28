# Shared by the hooks, which source it from their own folder: . "$(dirname "$0")/checks.sh"
# A missing copy makes the hook fail, so a hook never passes for want of its checks.
# Plumbing only, so a project's diff settings (textconv, external diffs, colour) change nothing.

hooks_dir="$(dirname "$0")"
fail=0
refuse() {
    echo "$(basename "$0"): $1" >&2
    fail=1
}

# In CI, scripts/ci-checks.sh sets CHECK_COMMIT to the commit to check, read in place of the staged changes, and
# CHECK_BASE to the pull request's base, whose CODEOWNERS and .gitignore count in place of HEAD's.
owners_ref="${CHECK_BASE:-HEAD}"
# The commit the changes are compared with: HEAD, or CHECK_COMMIT's parent; the empty tree when there's none.
parent="${CHECK_COMMIT:+$CHECK_COMMIT^}"
base="$(git rev-parse -q --verify "${parent:-HEAD}")" ||
    base="$(git hash-object -t tree /dev/null)"

# changes <diff options> [-- <pathspec>...]: the staged changes, or CHECK_COMMIT's.
changes() {
    if [ -n "$CHECK_COMMIT" ]; then git diff-tree -r "$base" "$CHECK_COMMIT" "$@"; else git diff-index "$base" --cached "$@"; fi
}

# staged_paths: the paths the commit adds or changes, one per line; deletions left out, renames as an add.
staged_paths() { changes --no-renames --diff-filter=d --name-only -z | tr '\0' '\n'; }

# added_lines [pathspec...]: the lines the commit adds, read only inside hunks, so the +++ headers never count.
# --text, so a -diff attribute can't hide a file's lines.
added_lines() {
    changes -p --text --no-renames -U0 -- "$@" |
        awk '/^diff --git /{ hunk = 0; next } /^@@/{ hunk = 1; next } hunk && /^\+/{ print substr($0, 2) }'
}

# scrub <what>: the text on stdin against the word list in .git/info/scrub-words. Not in CI: the list never
# leaves the machine.
scrub() { [ -n "$CHECK_COMMIT" ] || ${SH:-sh} "$hooks_dir/scrub.sh" "$1"; }

# matching <rules>: the NUL-separated paths on stdin that git's ignore rules in <rules> match, one per line, and no
# other rules: they're matched in an empty throwaway repository, as its core.excludesFile, with case counting.
# Not its info/exclude: a git template without info/ would leave nothing to write it in.
# Its git runs with the hook's variables unset, or it would act on the project (GIT_DIR is set in a linked worktree).
# Exits 0 when a path matches, 1 when none does, and 2, with a message, when it couldn't match at all.
matching() (
    unset $(git rev-parse --local-env-vars)
    if tmp="$(mktemp -d 2>/dev/null)" && git init -q "$tmp" && printf '%s\n' "$1" > "$tmp/rules"; then
        git -C "$tmp" -c core.excludesFile="$tmp/rules" -c core.ignorecase=false check-ignore --no-index --stdin -z > "$tmp/out"
        status=$?
        tr '\0' '\n' < "$tmp/out"
    else
        status=2
    fi
    [ -n "$tmp" ] && rm -rf "$tmp"
    [ "$status" -le 1 ] && exit "$status"
    echo "$(basename "$0"): couldn't match paths against git's ignore rules" >&2
    exit 2
)

# notes_private: whether docs/ holds private notes: a repository of its own, or ignored by the working tree's
# rules or by HEAD's .gitignore (the base's in CI), so emptying .gitignore doesn't make them public. --no-index,
# since a tracked file in docs/ would otherwise make it count as not ignored.
notes_private() {
    [ -e docs/.git ] && return 0
    git check-ignore -q --no-index docs/ 2>/dev/null && return 0
    gitignore="$(git cat-file blob "$owners_ref:.gitignore" 2>/dev/null)" || return 1
    # A match that couldn't run counts as private.
    printf 'docs/\0' | matching "$gitignore" >/dev/null
    [ $? -ne 1 ]
}

# codeowners: HEAD's CODEOWNERS (the base's in CI), the first of the places GitHub looks; the notes' copy is
# skipped where they're private. Not the commit's own, so a commit can't drop a path from the list and change it at
# once; in CI, not even in two commits of one pull request.
codeowners() {
    for f in .github/CODEOWNERS CODEOWNERS docs/CODEOWNERS; do
        [ "$f" = docs/CODEOWNERS ] && notes_private && continue
        git cat-file blob "$owners_ref:$f" 2>/dev/null && return
    done
}

# owner_patterns: the patterns CODEOWNERS lists, each line's first field; ! lines are dropped, since GitHub
# rejects them and git would un-protect. git's matching is wider than GitHub's (a/* also matches a/b/c, and a
# line without an owner still counts), so it errs toward protecting.
owner_patterns() { codeowners | awk '$1 !~ /^[#!]/ && NF { print $1 }'; }

# protected_paths: the paths the commit adds, changes or deletes that CODEOWNERS lists, one per line. Without
# renames, so a file moved out of a protected folder counts. Fails when the match couldn't run.
protected_paths() {
    patterns="$(owner_patterns)"
    [ -n "$patterns" ] || return 0
    changes --no-renames --name-only -z | matching "$patterns"
    [ $? -le 1 ]
}

# private_paths: the paths on stdin that are private notes: docs in any mode (folder, gitlink, link), anything
# under it, and the root AGENTS.md and CLAUDE.md. A nested AGENTS.md belongs to the project.
private_paths() { grep -E '^(docs|docs/.*|AGENTS\.md|CLAUDE\.md)$'; }

# notes_links: the lines on stdin that name a path into the private notes: docs/ at the start of the line or after
# a space, a quote, a bracket, >, a backtick, =, :, a comma, a bar, ./ or ../, once URLs are removed. A URL ends at a
# space or at one of ) ] > | , which links and tables put after it. sub/docs/ is the project's.
notes_links() {
    sed -E 's#[A-Za-z][A-Za-z0-9+.-]*://[^]|),>[:space:]]*##g' | grep -E "(^|[[:space:]\"'([{<>\`=:,|]|\.\.?/)docs/"
}
