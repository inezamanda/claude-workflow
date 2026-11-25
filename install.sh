#!/bin/sh
# Sets up Claude Code on this machine with this workflow. Safe to run again: each step is skipped when done.
#
#   install.sh              the clone, ~/.claude/CLAUDE.md, the plugins and graphify
#
# After the first run it's on the PATH as claude-workflow.
# Without a clone: curl -fsSL https://raw.githubusercontent.com/inezamanda/claude-workflow/main/install.sh | sh

REPO_URL="${CLAUDE_WORKFLOW_REPO_URL:-https://github.com/inezamanda/claude-workflow.git}"
failed=0

say() { printf '%s\n' "$*"; }
skip() { printf 'claude-workflow: %s\n' "$*" >&2; }
fail() {
    printf 'claude-workflow: %s\n' "$*" >&2
    failed=1
}

usage() {
    sed -n '3,5p' "$0" 2>/dev/null | sed 's/^# \{0,1\}//'
}

# The clone this script runs from (through the claude-workflow link too), or ~/.claude-workflow when it was
# piped in from curl.
find_repo() {
    file="$0"
    while [ -L "$file" ]; do
        target="$(readlink "$file")"
        case "$target" in
            /*) file="$target" ;;
            *) file="$(dirname "$file")/$target" ;;
        esac
    done
    dir="$(cd "$(dirname "$file")" 2>/dev/null && pwd -P)"
    if [ -n "$dir" ] && [ -f "$dir/install.sh" ] && [ -f "$dir/core/CLAUDE.md" ]; then
        repo="$dir"
        return
    fi
    repo="$HOME/.claude-workflow"
    if [ ! -d "$repo/.git" ]; then
        git clone -q "$REPO_URL" "$repo" && say "cloned the workflow to $repo" ||
            { fail "couldn't clone $REPO_URL"; exit 1; }
    fi
}

# Pulls only on a branch that tracks one, and only fast-forward, so local work is never touched.
update_repo() {
    git -C "$repo" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1 || return 0
    git -C "$repo" pull -q --ff-only || skip "couldn't update $repo; using it as it is"
}

# link <target> <path>: a symlink at path, moving anything else that's there to a dated backup first.
link() {
    if [ -L "$2" ] && [ "$(readlink "$2")" = "$1" ]; then
        return
    fi
    mkdir -p "$(dirname "$2")" || { fail "couldn't create $(dirname "$2")"; return; }
    if [ -e "$2" ] || [ -L "$2" ]; then
        backup="$2.backup.$(date +%Y%m%d%H%M%S)"
        mv "$2" "$backup" && say "moved the old $2 to $backup" || { fail "couldn't move $2 aside"; return; }
    fi
    ln -s "$1" "$2" && say "linked $2" || fail "couldn't link $2"
}

# plugins <plugin@marketplace=owner/repo>...: installs each plugin that isn't installed yet.
plugins() {
    if ! command -v claude >/dev/null 2>&1; then
        skip "Claude Code isn't installed, so the plugins were skipped; install it and run claude-workflow again"
        return
    fi
    installed="$(claude plugin list 2>/dev/null)"
    markets="$(claude plugin marketplace list 2>/dev/null)"
    for entry in "$@"; do
        plugin="${entry%%=*}"
        source="${entry#*=}"
        case "$installed" in *"$plugin"*) continue ;; esac
        case "$markets" in
            *"($source)"*) ;;
            *) claude plugin marketplace add "$source" >/dev/null || { fail "couldn't add the marketplace $source"; continue; } ;;
        esac
        claude plugin install "$plugin" >/dev/null && say "installed $plugin" || fail "couldn't install $plugin"
    done
}

graphify_tool() {
    if ! command -v graphify >/dev/null 2>&1; then
        if ! command -v uv >/dev/null 2>&1; then
            skip "uv isn't installed, so graphify was skipped; see https://docs.astral.sh/uv/"
            return
        fi
        uv tool install -q graphifyy && say "installed graphify" || { fail "couldn't install graphify"; return; }
        command -v graphify >/dev/null 2>&1 ||
            { skip "graphify is installed but not on the PATH yet; open a new shell and run claude-workflow again"; return; }
    fi
    [ -d "$HOME/.claude/skills/graphify" ] && return
    graphify install --platform claude >/dev/null && say "installed graphify's Claude skill" ||
        fail "couldn't install graphify's Claude skill"
}

machine() {
    update_repo
    link "$repo/core/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
    link "$repo/install.sh" "$HOME/.local/bin/claude-workflow"
    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) skip "add ~/.local/bin to your PATH to run claude-workflow by name" ;;
    esac
    plugins \
        caveman@caveman=JuliusBrussee/caveman \
        ponytail@ponytail=DietrichGebert/ponytail \
        superpowers@claude-plugins-official=anthropics/claude-plugins-official
    graphify_tool
}

case "${1:-}" in
    "") ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac

find_repo
machine
[ "$failed" -eq 0 ] && say "done" || exit 1
