#!/bin/sh
# Sets up Claude Code on this machine with this workflow. Safe to run again: each step is skipped when done.
#
#   install.sh                    the clone, ~/.claude/CLAUDE.md and AGENTS.md, the plugins and graphify
#   install.sh project            the same, then the templates into the current folder
#   install.sh project --apple    also the Apple coding guide and code smells, swift-lsp and the Swift skills
#
# After the first run it's on the PATH as agent-workflow.
# Without a clone: curl -fsSL https://raw.githubusercontent.com/inezamanda/agent-workflow/main/install.sh | sh

REPO_URL="${AGENT_WORKFLOW_REPO_URL:-https://github.com/inezamanda/agent-workflow.git}"
failed=0

say() { printf '%s\n' "$*"; }
skip() { printf 'agent-workflow: %s\n' "$*" >&2; }
fail() {
    printf 'agent-workflow: %s\n' "$*" >&2
    failed=1
}

usage() {
    sed -n '3,7p' "$0" 2>/dev/null | sed 's/^# \{0,1\}//'
}

# The clone this script runs from (through the agent-workflow link too), or ~/.agent-workflow when it was
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
    new="$HOME/.agent-workflow" old="$HOME/.claude-workflow"
    if [ -n "$dir" ] && [ -f "$dir/install.sh" ] && [ -f "$dir/core/global/CLAUDE.md" ]; then
        repo="$dir"
    else
        repo="$new"
    fi
    # The clone was called ~/.claude-workflow before the repository was renamed: move it once. A clone kept
    # anywhere else is the maintainer's own, and stays where it is.
    if { [ "$repo" = "$old" ] || [ "$repo" = "$new" ]; } && [ -d "$old/.git" ]; then
        if [ -e "$new" ]; then
            skip "$new is there too, so it left $old as it is"
        else
            mv "$old" "$new" && say "moved $old to $new" || { fail "couldn't move $old to $new"; exit 1; }
            repo="$new"
        fi
    fi
    if [ "$repo" = "$new" ] && [ ! -d "$repo/.git" ]; then
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
        skip "Claude Code isn't installed, so the plugins were skipped; install it and run agent-workflow again"
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
            { skip "graphify is installed but not on the PATH yet; open a new shell and run agent-workflow again"; return; }
    fi
    [ -d "$HOME/.claude/skills/graphify" ] && return
    graphify install --platform claude >/dev/null && say "installed graphify's Claude skill" ||
        fail "couldn't install graphify's Claude skill"
}

machine() {
    update_repo
    link "$repo/core/global/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
    # Claude Code resolves CLAUDE.md's @AGENTS.md from the link's target, core/global/. A link beside it, made
    # by earlier versions, only loaded the rules a second time through plugins that look for ~/.claude/AGENTS.md.
    old_agents="$HOME/.claude/AGENTS.md"
    case "$(readlink "$old_agents" 2>/dev/null)" in
        */core/global/AGENTS.md) rm "$old_agents" && say "removed the ~/.claude/AGENTS.md link; CLAUDE.md imports it already" ;;
    esac
    link "$repo/install.sh" "$HOME/.local/bin/agent-workflow"
    # The command was called claude-workflow before the rename; its link only ever pointed at this script.
    old_command="$HOME/.local/bin/claude-workflow"
    if [ -L "$old_command" ] && [ "$(basename "$(readlink "$old_command")")" = install.sh ]; then
        rm "$old_command" && say "removed the old claude-workflow command; it's agent-workflow now"
    fi
    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) skip "add ~/.local/bin to your PATH to run agent-workflow by name" ;;
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

# above <file in the clone>: prints the first CLAUDE.md in a folder above this one with the same text, if any.
# Claude Code loads those too, so a copy here would load the same rules twice.
above() {
    dir="$(dirname "$(pwd -P)")"
    while :; do
        [ -f "$dir/CLAUDE.md" ] && cmp -s "$dir/CLAUDE.md" "$repo/$1" && { say "$dir/CLAUDE.md"; return 0; }
        [ "$dir" = / ] && return 1
        dir="$(dirname "$dir")"
    done
}

project() {
    if [ "$(pwd -P)" = "$repo" ]; then
        fail "this is the workflow's own clone; run agent-workflow project in the project's folder"
        return
    fi
    top="$(git rev-parse --show-toplevel 2>/dev/null)"
    if [ -n "$top" ] && [ "$(cd "$top" && pwd -P)" != "$(pwd -P)" ]; then
        fail "the templates go at the repository's root; run agent-workflow project in $top"
        return
    fi
    # Before the rename the principles were copied as docs/CLAUDE.md, often adapted past recognition, so any
    # docs/CLAUDE.md is taken for them: renamed by hand, never loaded twice.
    old_principles=0
    if [ ! -e docs/principles.md ] && [ -e docs/CLAUDE.md ]; then
        old_principles=1
        skip "docs/CLAUDE.md is already there, so the principles weren't added. If it holds them, run git mv docs/CLAUDE.md docs/principles.md, then change docs/CLAUDE.md to docs/principles.md wherever AGENTS.md or CLAUDE.md names it. If it doesn't, copy $repo/core/principles.md to docs/principles.md"
    else
        copy core/principles.md docs/principles.md
    fi
    copy core/CONTRIBUTING.md CONTRIBUTING.md
    copy core/hooks/commit-msg scripts/hooks/commit-msg
    copy core/agents/code-reviewer.md .claude/agents/code-reviewer.md
    copy core/github/review.yml .github/workflows/review.yml
    copy core/github/pull_request_template.md .github/pull_request_template.md
    copy core/templates/spec.md docs/templates/spec.md
    copy core/templates/decisions.md docs/templates/decisions.md
    copy core/templates/edge-list.md docs/templates/edge-list.md
    copy core/skills/README.md .agents/skills/README.md

    # Every other tool reads skills from .agents/skills; Claude Code reads .claude/skills, so it gets a link.
    if [ "$(readlink .claude/skills 2>/dev/null)" != ../.agents/skills ]; then
        if [ -e .claude/skills ] || [ -L .claude/skills ]; then
            skip ".claude/skills is already there; move its skills to .agents/skills, then run: ln -s ../.agents/skills .claude/skills"
        else
            mkdir -p .claude && ln -s ../.agents/skills .claude/skills && say "linked .claude/skills to .agents/skills" ||
                fail "couldn't link .claude/skills"
        fi
    fi

    # Two branches that each add rows to the append-only decisions log then merge without a conflict.
    union="docs/decisions.md merge=union"
    if [ ! -e .gitattributes ]; then
        printf '%s\n' "$union" > .gitattributes && say "added .gitattributes" || fail "couldn't add .gitattributes"
    elif ! grep -qxF "$union" .gitattributes; then
        skip ".gitattributes is already there; add this line to it to merge the decisions log:"
        printf '  %s\n' "$union" >&2
    fi

    reads="CONTRIBUTING.md docs/principles.md"
    if [ "$apple" = 1 ]; then
        copy apple/CODING.md CODING.md
        reads="CONTRIBUTING.md CODING.md docs/principles.md"
        if smells="$(above apple/CLAUDE.md)"; then
            skip "$smells already has the code smells and is loaded here, so docs/code-smells.md wasn't added"
        else
            copy apple/CLAUDE.md docs/code-smells.md
            reads="$reads docs/code-smells.md"
        fi
    fi

    # An AGENTS.md or CLAUDE.md that's already there may hold the project's own rules, so it's never rewritten.
    # Every tool reads AGENTS.md, which says what to read; Claude Code reads CLAUDE.md, which imports the same files.
    if [ ! -e AGENTS.md ]; then
        list="$(printf '%s\n' $reads | sed 's/.*/- `&`/')" awk '
            $0 == "<!-- files to read -->" { print ENVIRON["list"]; next }
            { print }' "$repo/core/project/AGENTS.md" > AGENTS.md && say "added AGENTS.md, which lists what to read" ||
            fail "couldn't add AGENTS.md"
    else
        missing=""
        for f in $reads; do
            # The rename above gives this one.
            [ "$old_principles" = 1 ] && [ "$f" = docs/principles.md ] && continue
            grep -qF "$f" AGENTS.md || missing="$missing $f"
        done
        if [ -n "$missing" ]; then
            skip "AGENTS.md is already there; add these to the files it says to read:"
            printf '  %s\n' $missing >&2
        fi
    fi
    if [ ! -e CLAUDE.md ]; then
        { cat "$repo/core/project/CLAUDE.md" && printf '@%s\n' $reads; } > CLAUDE.md &&
            say "added CLAUDE.md, which imports AGENTS.md and the others" || fail "couldn't add CLAUDE.md"
    else
        missing=""
        for line in @AGENTS.md $(printf '@%s ' $reads); do
            [ "$old_principles" = 1 ] && [ "$line" = @docs/principles.md ] && continue
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
