#!/bin/sh
# Sets up Claude Code on this machine with this workflow. Safe to run again: each step is skipped when done.
#
#   install.sh                    the clone, ~/.claude/CLAUDE.md, the plugins and graphify
#   install.sh project            the same, then the templates into the current folder
#   install.sh project --apple    also the Apple coding guide and code smells, swift-lsp and the Swift skills
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
    sed -n '3,7p' "$0" 2>/dev/null | sed 's/^# \{0,1\}//'
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

# copy <from, in the clone> <to, in this folder>: never over a file that's already there.
copy() {
    if [ -e "$2" ]; then
        say "kept $2, which is already there"
        return
    fi
    mkdir -p "$(dirname "$2")" && cp "$repo/$1" "$2" && say "added $2" || fail "couldn't add $2"
}

project() {
    if [ "$(pwd -P)" = "$repo" ]; then
        fail "this is the workflow's own clone; run claude-workflow project in the project's folder"
        return
    fi
    top="$(git rev-parse --show-toplevel 2>/dev/null)"
    if [ -n "$top" ] && [ "$(cd "$top" && pwd -P)" != "$(pwd -P)" ]; then
        fail "the templates go at the repository's root; run claude-workflow project in $top"
        return
    fi
    copy core/principles.md docs/CLAUDE.md
    copy core/CONTRIBUTING.md CONTRIBUTING.md
    copy core/hooks/commit-msg scripts/hooks/commit-msg
    copy core/agents/code-reviewer.md .claude/agents/code-reviewer.md
    copy core/github/review.yml .github/workflows/review.yml
    copy core/github/pull_request_template.md .github/pull_request_template.md
    imports="@CONTRIBUTING.md @docs/CLAUDE.md"
    if [ "$apple" = 1 ]; then
        copy apple/CODING.md CODING.md
        copy apple/CLAUDE.md docs/code-smells.md
        imports="@CONTRIBUTING.md @CODING.md @docs/CLAUDE.md @docs/code-smells.md"
    fi

    # A CLAUDE.md that's already there may hold the project's own rules, so it's never rewritten.
    if [ ! -e CLAUDE.md ]; then
        printf '%s\n' $imports > CLAUDE.md && say "added CLAUDE.md, which imports the others" || fail "couldn't add CLAUDE.md"
    else
        missing=""
        for line in $imports; do
            grep -qxF "$line" CLAUDE.md || missing="$missing $line"
        done
        if [ -n "$missing" ]; then
            skip "CLAUDE.md is already there; add these lines to it to import the templates:"
            printf '  %s\n' $missing >&2
        fi
    fi

    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        skip "this folder isn't a git repository yet; after git init, run: git config core.hooksPath scripts/hooks"
    else
        hooks="$(git config core.hooksPath)"
        if [ -z "$hooks" ]; then
            git config core.hooksPath scripts/hooks && say "set core.hooksPath to scripts/hooks" || fail "couldn't set core.hooksPath"
        elif [ "$hooks" != scripts/hooks ]; then
            skip "core.hooksPath is already $hooks, so it was kept; move scripts/hooks/commit-msg there to use it"
        fi
    fi

    [ "$apple" = 1 ] && plugins \
        swift-lsp@claude-plugins-official=anthropics/claude-plugins-official \
        swift-concurrency-pro@swift-concurrency-agent-skill=twostraws/Swift-Concurrency-Agent-Skill \
        swiftui-pro@swiftui-agent-skill=twostraws/SwiftUI-Agent-Skill \
        swift-testing-pro@swift-testing-agent-skill=twostraws/Swift-Testing-Agent-Skill
}

mode=machine apple=0
case "${1:-}" in
    "") ;;
    project)
        mode=project
        case "${2:-}" in
            "") ;;
            --apple) apple=1 ;;
            *)
                usage >&2
                exit 2
                ;;
        esac
        ;;
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
[ "$mode" = project ] && project
[ "$failed" -eq 0 ] && say "done" || exit 1
