#!/bin/sh
# Sets up Claude Code on this machine with this workflow. Safe to run again: each step is skipped when done.
#
#   install.sh                    the clone, ~/.claude/CLAUDE.md and AGENTS.md, the plugins and graphify
#   install.sh project            the same, then the templates into the current folder
#   install.sh project --apple    also the Apple coding guide and code smells, the Swift lint configs, hook and CI,
#                                  swift-lsp, the Swift skills, three Instruments skills and the Xcode plugin
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
    sed -n '3,8p' "$0" 2>/dev/null | sed 's/^# \{0,1\}//'
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

# xcode_plugin: Apple's Xcode plugin, for this project at local scope. It's installed by running a command the
# marketplace declares; Claude Code shows that command and asks a person to accept it, so it's accepted here only
# when it's the one below, by the sha256 the refused --json run reported.
xcode_plugin() {
    command -v claude >/dev/null 2>&1 || return # plugins already said they were skipped
    if ! xcrun agent plugin path --plugin-format claude >/dev/null 2>&1; then
        skip "Apple's Xcode plugin was skipped: install Xcode 27 or later, then run agent-workflow project --apple again"
        return
    fi
    # Claude Code keys a local install by the main worktree's physical path, so linked worktrees share it; outside
    # a repository, by this folder.
    root="$(git worktree list --porcelain 2>/dev/null | sed -n '1s/^worktree //p')"
    root="$(cd "${root:-.}" && pwd -P)"
    # Python, from Xcode, is there once xcrun agent is; JSON in sh is guesswork.
    claude plugin list --json 2>/dev/null | python3 -I -c '
import json, sys
sys.exit(not any(p.get("id") == "xcode@claude-plugins-official" and p.get("scope") == "local"
                 and p.get("projectPath") == sys.argv[1] for p in json.load(sys.stdin)))' "$root" && return
    expected="xcrun agent plugin path --plugin-format claude"
    shown="$(claude plugin install xcode@claude-plugins-official --scope local --json </dev/null 2>/dev/null | tail -n 1)"
    # "ok" when it installed already, since Claude Code remembers a command a person accepted; "failed" when it
    # failed with no command or sha shown; empty when the command shown, or how it's run, isn't the expected one.
    sha="$(printf '%s' "$shown" | python3 -I -c '
import json, sys
d = json.load(sys.stdin)
c = d.get("shownCommand")
if d.get("outcome") == "ok": print("ok")
elif not c or not c.get("sha256"): print("failed")
elif (c.get("kind"), c.get("command"), c.get("mode")) == ("command_source", sys.argv[1], "link"): print(c["sha256"])' \
        "$expected" 2>/dev/null || echo failed)"
    xcode_added="installed xcode@claude-plugins-official for this project; Xcode asks you to approve each agent the first time it opens or creates a project through Xcode's tools"
    not_installed="couldn't install Apple's Xcode plugin; to see why, run: claude plugin install xcode@claude-plugins-official --scope local"
    case "$sha" in
        ok) say "$xcode_added" ;;
        failed) skip "$not_installed" ;;
        "")
            skip "Apple's Xcode plugin wasn't installed: its marketplace no longer shows the expected command ($expected). What it showed:"
            printf '  %s\n' "$shown" >&2
            skip "if that's safe to run, install it in your own terminal: claude plugin install xcode@claude-plugins-official --scope local" ;;
        *)
            claude plugin install xcode@claude-plugins-official --scope local --accept-command "$sha" >/dev/null 2>&1 &&
                say "$xcode_added" || skip "$not_installed" ;;
    esac
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

# guard <from, in the clone> <to>: copy, and when a copy is kept, warn if it differs from the clone's, which may
# check more by now. It's never replaced: a project may have its own. commit-msg's ALLOW_AI_CREDIT is the project's.
guard() {
    copy "$1" "$2"
    [ "$(grep -v '^ALLOW_AI_CREDIT=' "$2")" = "$(grep -v '^ALLOW_AI_CREDIT=' "$repo/$1")" ] ||
        skip "$2 differs from $repo/$1, which may check more by now; compare them with: diff $2 $repo/$1"
}

# ignore <path> <why> [committed]: appends /<path> to .gitignore, unless it's ignored already. With committed, only
# a line of .gitignore itself counts, not a local rule (.git/info/exclude, global excludes) that CI never sees.
ignore() {
    # check-ignore fails outside a repository, so the line itself is looked for too.
    grep -qxF "/$1" .gitignore 2>/dev/null && return
    if [ "${3:-}" = committed ]; then
        grep -qxE "/?${1%/}/?" .gitignore 2>/dev/null && return
    else
        git check-ignore -q --no-index "$1" 2>/dev/null && return
    fi
    # A last line without a newline would run into the new one.
    [ -s .gitignore ] && [ -n "$(tail -c 1 .gitignore)" ] && echo >> .gitignore
    printf '/%s\n' "$1" >> .gitignore && say "added /$1 to .gitignore, $2" || fail "couldn't add /$1 to .gitignore"
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
    # The notes are private when docs/ is a repository of its own or git-ignored. Then AGENTS.md and CLAUDE.md, which
    # name files in docs/, stay out of the public repository too, and the union line goes in docs/ beside the log.
    # --no-index, since a tracked file in docs/ would otherwise make it count as not ignored.
    private=0
    { [ -e docs/.git ] || git check-ignore -q --no-index docs/ 2>/dev/null; } && private=1

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
    grep -q '^- \*\*Types:\*\*' CONTRIBUTING.md 2>/dev/null ||
        skip "CONTRIBUTING.md has no \"- **Types:**\" line, so scripts/hooks/commit-msg refuses every commit; add one that lists the types in backticks, as $repo/core/CONTRIBUTING.md does"
    for f in commit-msg pre-commit post-checkout checks.sh scrub.sh; do
        guard "core/hooks/$f" "scripts/hooks/$f"
    done
    # CI runs the hooks again on every commit of a pull request, which kept hooks from before CI would fail.
    guard core/checks/ci-checks.sh scripts/ci-checks.sh
    older=""
    for f in commit-msg pre-commit checks.sh; do
        grep -q CHECK_COMMIT "scripts/hooks/$f" 2>/dev/null || older="$older $f"
    done
    if [ -z "$older" ]; then
        guard core/github/checks.yml .github/workflows/checks.yml
    else
        skip ".github/workflows/checks.yml wasn't added: the kept scripts/hooks/{$(echo $older | tr ' ' ,)} are from before CI, so it would fail every pull request, and they miss newer checks such as the Protected: line. Replace them with $repo/core/hooks/'s (keep commit-msg's ALLOW_AI_CREDIT), then run agent-workflow project again"
    fi
    # The hooks protect the paths CODEOWNERS lists, read from the first place GitHub looks. Beside a project's own
    # file a new one would win over it, so the template's missing lines are printed instead.
    owners=""
    for f in .github/CODEOWNERS CODEOWNERS docs/CODEOWNERS; do
        [ "$f" = docs/CODEOWNERS ] && [ "$private" = 1 ] && continue
        [ -e "$f" ] && owners="$f" && break
    done
    if [ -z "$owners" ]; then
        copy core/github/CODEOWNERS .github/CODEOWNERS
    else
        # The template protects itself as /.github/CODEOWNERS; here the file to protect is the project's own.
        # The Swift configs' lines only with --apple, since only then does it add those files.
        lines="$(awk -v own="/$owners" -v apple="$apple" 'NR == FNR { have[$1]; next }
            $1 == "/.github/CODEOWNERS" { $1 = own }
            !apple && ($1 == "/.swiftlint.yml" || $1 == "/.swift-format") { next }
            NF && $1 !~ /^#/ && !($1 in have)' "$owners" "$repo/core/github/CODEOWNERS")"
        if [ -n "$lines" ]; then
            skip "$owners is already there; add these lines to it, so the hooks protect the guards:"
            printf '%s\n' "$lines" | sed 's/^/  /' >&2
        fi
        awk '$1 == "*" { found = 1 } END { exit !found }' "$owners" &&
            skip "$owners has a catch-all * line, so the hooks ask every commit for a \"Protected: <why>\" line"
    fi
    # Claude asks before it edits a path CODEOWNERS lists. A settings.json of the project's own is never merged into.
    guard core/claude/protected-edit.sh .claude/hooks/protected-edit.sh
    if [ ! -e .claude/settings.json ]; then
        copy core/claude/settings.json .claude/settings.json
    elif ! grep -q 'protected-edit\.sh' .claude/settings.json; then
        skip ".claude/settings.json is already there; add this hook to it, so Claude asks before it edits a path CODEOWNERS lists:"
        sed 's/^/  /' "$repo/core/claude/settings.json" >&2
    fi
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
    attributes=.gitattributes union="docs/decisions.md merge=union"
    [ "$private" = 1 ] && attributes=docs/.gitattributes union="decisions.md merge=union"
    if [ ! -e "$attributes" ]; then
        printf '%s\n' "$union" > "$attributes" && say "added $attributes" || fail "couldn't add $attributes"
    elif ! grep -qxF "$union" "$attributes"; then
        skip "$attributes is already there; add this line to it to merge the decisions log:"
        printf '  %s\n' "$union" >&2
    fi

    reads="CONTRIBUTING.md docs/principles.md"
    if [ "$apple" = 1 ]; then
        copy apple/CODING.md CODING.md
        copy apple/swift-format.json .swift-format
        copy apple/swiftlint.yml .swiftlint.yml
        copy apple/github/checks-swift.yml .github/workflows/checks-swift.yml
        # Axiom's Instruments skills; MIT wants its notice with every copy, so LICENSE goes too.
        for s in performance-profiling memory-debugging swiftui-performance; do
            for f in SKILL.md LICENSE SOURCE.md; do copy "apple/skills/$s/$f" ".agents/skills/$s/$f"; done
        done
        grep -q '^  PACKAGES: ""' .github/workflows/checks-swift.yml 2>/dev/null &&
            say "to test Swift packages on Linux in CI, list them in PACKAGES in .github/workflows/checks-swift.yml"
        guard apple/hooks/pre-commit-swift scripts/hooks/pre-commit-swift
        grep -q pre-commit-swift scripts/hooks/pre-commit 2>/dev/null ||
            skip "the kept scripts/hooks/pre-commit doesn't run scripts/hooks/pre-commit-swift, so the Swift step won't run; replace it with $repo/core/hooks/pre-commit"
        reads="CONTRIBUTING.md CODING.md docs/principles.md"
        if smells="$(above apple/CLAUDE.md)"; then
            skip "$smells already has the code smells and is loaded here, so docs/code-smells.md wasn't added"
        else
            copy apple/CLAUDE.md docs/code-smells.md
            reads="$reads docs/code-smells.md"
        fi
    fi

    # Before AGENTS.md and CLAUDE.md are written or checked, so an untrack message comes before any list of
    # private files to add to them.
    if [ "$private" = 1 ]; then
        for f in AGENTS.md CLAUDE.md; do
            ignore "$f" "since it names the private notes"
            git ls-files --error-unmatch "$f" >/dev/null 2>&1 &&
                skip "$f is tracked, but where the notes are private it mustn't be; untrack it first with: git rm --cached $f"
        done
        # So CI and a linked worktree, which see only the committed .gitignore (a worktree has no docs/), still
        # find the notes private.
        ignore docs/ "so CI and linked worktrees, which read only .gitignore, find the notes private" committed
        grep -qxF "docs/decisions.md merge=union" .gitattributes 2>/dev/null &&
            skip "the root .gitattributes still merges the decisions log, which is in the private notes now; remove its line docs/decisions.md merge=union"
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
            swift="" && [ "$apple" = 1 ] && swift=", pre-commit-swift"
            skip "core.hooksPath is already $hooks, so it was kept; move scripts/hooks/commit-msg, pre-commit$swift, post-checkout, checks.sh and scrub.sh there to use them"
        fi
        list="$(git rev-parse --git-path info/scrub-words)"
        grep -q '[^[:space:]]' "$list" 2>/dev/null ||
            skip "the hooks refuse every commit until $list lists the words to keep out of the repository, one per line, such as real names; it stays in .git, so it's never committed"
    fi

    [ "$apple" = 1 ] && plugins \
        swift-lsp@claude-plugins-official=anthropics/claude-plugins-official \
        swift-concurrency-pro@swift-concurrency-agent-skill=twostraws/Swift-Concurrency-Agent-Skill \
        swiftui-pro@swiftui-agent-skill=twostraws/SwiftUI-Agent-Skill \
        swift-testing-pro@swift-testing-agent-skill=twostraws/Swift-Testing-Agent-Skill
    if [ "$apple" = 1 ]; then
        # A local install's setting is this Mac's; even a refused install writes the file.
        ignore .claude/settings.local.json "since it holds this Mac's own Claude settings" committed
        xcode_plugin
    fi
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
