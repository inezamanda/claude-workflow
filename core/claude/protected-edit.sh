#!/bin/sh
# Claude Code's PreToolUse hook for Edit, Write and NotebookEdit: asks before an edit of a path CODEOWNERS lists,
# since a commit that changes it needs a "Protected: <why>" line. The path is matched against the checkout that
# holds it, a worktree under .claude/worktrees/ or beside the project included, with that checkout's HEAD:CODEOWNERS,
# using the main checkout's scripts/hooks/checks.sh, so there's one matcher. A path in no git checkout gets no
# answer, so Claude's own rules apply. When it can't check (no path, no jq, no checks.sh, a match that can't run), it asks.
# Install it as .claude/hooks/protected-edit.sh, with the block in core/claude/settings.json.

ask() {
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' \
        "$(printf '%s' "$1" | sed 's/[\\"]/\\&/g')"
    exit 0
}

# NotebookEdit names its file notebook_path; Edit and Write, file_path. // empty, since jq prints null for neither.
JQ="${JQ:-jq}"
path="$("$JQ" -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null)" ||
    ask "protected-edit.sh couldn't check this edit: $JQ couldn't read its input (is jq installed?)"
[ -n "$path" ] || ask "protected-edit.sh couldn't check this edit: it names no file"
checks="$CLAUDE_PROJECT_DIR/scripts/hooks/checks.sh"
[ -f "$checks" ] || ask "protected-edit.sh couldn't check this edit: $checks is missing"

# The nearest folder that exists, and the part of the path below it that doesn't yet. git resolves links in it,
# so a path through a link, or /var for /private/var, gives the same checkout and prefix.
dir="$(dirname "$path")" rest="$(basename "$path")"
while [ ! -d "$dir" ]; do
    rest="$(basename "$dir")/$rest" dir="$(dirname "$dir")"
done
prefix="$(git -C "$dir" rev-parse --show-prefix 2>/dev/null)" || exit 0
top="$(git -C "$dir" rev-parse --show-toplevel)" && cd "$top" ||
    ask "protected-edit.sh couldn't check this edit: no checkout root for $path"

. "$checks"
patterns="$(owner_patterns)"
[ -n "$patterns" ] || exit 0
match="$(printf '%s\0' "$prefix$rest" | matching "$patterns" 2>/dev/null)"
[ $? -le 1 ] || ask "protected-edit.sh couldn't check this edit: matching $prefix$rest against CODEOWNERS failed"
[ -n "$match" ] && ask "$prefix$rest is listed in CODEOWNERS, so a commit that changes it needs a \"Protected: <why>\" line"
exit 0
