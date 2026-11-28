#!/bin/sh
# Runs install.sh against a throwaway HOME, with fake claude, uv and graphify commands that record their calls,
# so it never touches the real setup or the network.
# Usage: scripts/test-install.sh (from anywhere in the repository)

root="$(git rev-parse --show-toplevel)" || exit 1
# Outside any repository, so the project tests don't find this one around them.
work="$(mktemp -d "${TMPDIR:-/tmp}/test-install.XXXXXX")" || exit 1
work="$(cd "$work" && pwd -P)"
trap 'rm -rf "$work"' EXIT
failures=0

check() { # check <name> <command...>
    name="$1"
    shift
    if "$@" >/dev/null 2>&1; then echo "ok    $name"; else echo "FAIL  $name"; failures=$((failures + 1)); fi
}

# The repository as it is now, uncommitted files included, as a clone of its own.
src="$work/src"
mkdir -p "$src" && (cd "$root" && git ls-files -co --exclude-standard | while read -r f; do
    mkdir -p "$src/$(dirname "$f")" && cp -p "$f" "$src/$f"
done)
git -C "$src" init -q && git -C "$src" add -A && git -C "$src" -c user.name=t -c user.email=t@t commit -qm init

# Fakes. claude keeps its plugins and marketplaces in $STATE; uv "installs" a graphify that installs a skill.
fakes="$work/fakes" nofakes="$work/nofakes"
mkdir -p "$fakes" "$nofakes"
cat > "$fakes/claude" <<'EOF'
#!/bin/sh
echo "$*" >> "$STATE/log"
case "$*" in
    "plugin list") cat "$STATE/installed" 2>/dev/null ;;
    "plugin marketplace list") cat "$STATE/markets" 2>/dev/null ;;
    "plugin marketplace add "*) echo "  Source: GitHub ($4)" >> "$STATE/markets" ;;
    "plugin install "*) echo "  > $3" >> "$STATE/installed" ;;
esac
EOF
cat > "$fakes/uv" <<'EOF'
#!/bin/sh
echo "uv $*" >> "$STATE/log"
printf '#!/bin/sh\necho "graphify $*" >> "$STATE/log"\nmkdir -p "$HOME/.claude/skills/graphify"\n' > "$FAKES/graphify"
chmod +x "$FAKES/graphify"
EOF
chmod +x "$fakes/claude" "$fakes/uv"
export FAKES="$fakes"

# fresh <name>: a new HOME and fake state, where the official marketplace is already configured.
fresh() {
    export HOME="$work/$1" STATE="$work/$1-state"
    mkdir -p "$HOME" "$STATE"
    echo "  Source: GitHub (anthropics/claude-plugins-official)" > "$STATE/markets"
    rm -f "$fakes/graphify"
}
count() { grep -c "$1" "$STATE/log" 2>/dev/null || true; }
base="/usr/bin:/bin"

# From a clone, with an old CLAUDE.md in place
fresh one && mkdir -p "$HOME/.claude" && echo old > "$HOME/.claude/CLAUDE.md"
PATH="$fakes:$HOME/.local/bin:$base" "$src/install.sh" > "$work/out" 2>&1
check "first run succeeds" [ $? -eq 0 ]
check "CLAUDE.md links to the clone" [ "$(readlink "$HOME/.claude/CLAUDE.md")" = "$src/core/CLAUDE.md" ]
check "the old CLAUDE.md is kept as a backup" sh -c "cat '$HOME'/.claude/CLAUDE.md.backup.* | grep -qx old"
check "agent-workflow links to install.sh" [ "$(readlink "$HOME/.local/bin/agent-workflow")" = "$src/install.sh" ]
for p in caveman@caveman ponytail@ponytail superpowers@claude-plugins-official; do
    check "installs $p" [ "$(count "plugin install $p")" -eq 1 ]
done
check "adds the two missing marketplaces" [ "$(count "plugin marketplace add")" -eq 2 ]
check "doesn't add the official marketplace again" [ "$(count "marketplace add anthropics")" -eq 0 ]
check "installs graphify and its skill" [ -d "$HOME/.claude/skills/graphify" ]

# Again, through the agent-workflow link: nothing new happens
calls="$(wc -l < "$STATE/log")"
PATH="$fakes:$HOME/.local/bin:$base" agent-workflow > "$work/out" 2>&1
check "second run through the link succeeds" [ $? -eq 0 ]
check "second run installs nothing" [ "$(count "plugin install")" -eq 3 ]
check "second run calls only the two lists" [ "$(wc -l < "$STATE/log")" -eq $((calls + 2)) ]
check "second run makes no new backup" [ "$(ls "$HOME/.claude" | grep -c backup)" -eq 1 ]
check "the link doesn't make a second clone" [ ! -e "$HOME/.agent-workflow" ]

# Piped in, as from curl: it clones, and later updates the clone
fresh two && cd "$work" || exit 1
AGENT_WORKFLOW_REPO_URL="$src" PATH="$fakes:$base" sh < "$src/install.sh" > "$work/out" 2>&1
check "piped run succeeds" [ $? -eq 0 ]
check "piped run clones to ~/.agent-workflow" [ -f "$HOME/.agent-workflow/core/CLAUDE.md" ]
check "piped run links CLAUDE.md into that clone" [ "$(readlink "$HOME/.claude/CLAUDE.md")" = "$HOME/.agent-workflow/core/CLAUDE.md" ]
check "piped run warns that ~/.local/bin isn't on the PATH" grep -q "add ~/.local/bin to your PATH" "$work/out"
echo new > "$src/new-file" && git -C "$src" add new-file && git -C "$src" -c user.name=t -c user.email=t@t commit -qm new
PATH="$fakes:$base" "$HOME/.local/bin/agent-workflow" > "$work/out" 2>&1
check "a later run pulls the clone" [ -f "$HOME/.agent-workflow/new-file" ]

# A clone from before the rename, at ~/.claude-workflow, run through its old command: it moves to ~/.agent-workflow
fresh six && git clone -q "$src" "$HOME/.claude-workflow" && mkdir -p "$HOME/.claude" "$HOME/.local/bin" || exit 1
ln -s "$HOME/.claude-workflow/core/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
ln -s "$HOME/.claude-workflow/install.sh" "$HOME/.local/bin/claude-workflow"
AGENT_WORKFLOW_REPO_URL="$src" PATH="$fakes:$base" "$HOME/.local/bin/claude-workflow" > "$work/out" 2>&1
check "an old clone's run succeeds" [ $? -eq 0 ]
check "the old clone moves to ~/.agent-workflow" [ -f "$HOME/.agent-workflow/core/CLAUDE.md" ]
check "the old clone is gone from ~/.claude-workflow" [ ! -e "$HOME/.claude-workflow" ]
check "it says it moved the clone" grep -q "moved $HOME/.claude-workflow to" "$work/out"
check "CLAUDE.md links into the moved clone" [ "$(readlink "$HOME/.claude/CLAUDE.md")" = "$HOME/.agent-workflow/core/CLAUDE.md" ]
check "agent-workflow links into the moved clone" [ "$(readlink "$HOME/.local/bin/agent-workflow")" = "$HOME/.agent-workflow/install.sh" ]
check "the old claude-workflow command is gone" [ ! -L "$HOME/.local/bin/claude-workflow" ]

# Both clones there: nothing is moved, and it says so
fresh seven && git clone -q "$src" "$HOME/.claude-workflow" && git clone -q "$src" "$HOME/.agent-workflow" || exit 1
AGENT_WORKFLOW_REPO_URL="$src" PATH="$fakes:$base" "$HOME/.claude-workflow/install.sh" > "$work/out" 2>&1
check "with both clones, the run succeeds" [ $? -eq 0 ]
check "with both clones, the old one stays" [ -d "$HOME/.claude-workflow/.git" ]
check "with both clones, the new one stays" [ -d "$HOME/.agent-workflow/.git" ]
check "with both clones, it says it left the old one" grep -q "left $HOME/.claude-workflow as it is" "$work/out"

# Without Claude Code or uv: the links are still made, and it says what it skipped
fresh three
PATH="$nofakes:$base" "$src/install.sh" > "$work/out" 2>&1
check "run without claude or uv succeeds" [ $? -eq 0 ]
check "run without claude still links CLAUDE.md" [ -L "$HOME/.claude/CLAUDE.md" ]
check "run without claude says the plugins were skipped" grep -q "plugins were skipped" "$work/out"
check "run without uv says graphify was skipped" grep -q "graphify was skipped" "$work/out"

# An unknown argument
fresh four
PATH="$fakes:$base" "$src/install.sh" nonsense > "$work/out" 2>&1
check "an unknown argument exits 2" [ $? -eq 2 ]
check "an unknown argument changes nothing" [ ! -e "$HOME/.claude" ]

# project: a new git repository gets every template, a CLAUDE.md that imports them, and the hooks
fresh five && mkdir -p "$work/p1" && cd "$work/p1" && git init -q || exit 1
PATH="$fakes:$base" "$src/install.sh" project > "$work/out" 2>&1
check "project succeeds" [ $? -eq 0 ]
for f in docs/CLAUDE.md CONTRIBUTING.md scripts/hooks/commit-msg .claude/agents/code-reviewer.md \
    .github/workflows/review.yml .github/pull_request_template.md \
    docs/templates/spec.md docs/templates/decisions.md docs/templates/edge-list.md; do
    check "project adds $f" [ -f "$f" ]
done
check "project's .gitattributes merges the decisions log with union" grep -qxF "docs/decisions.md merge=union" .gitattributes
check "project adds no decisions log of its own" [ ! -e docs/decisions.md ]
check "project's CLAUDE.md imports CONTRIBUTING.md and docs/CLAUDE.md" \
    [ "$(cat CLAUDE.md)" = "$(printf '@CONTRIBUTING.md\n@docs/CLAUDE.md')" ]
check "project's commit-msg hook is executable" [ -x scripts/hooks/commit-msg ]
check "project sets core.hooksPath" [ "$(git config core.hooksPath)" = scripts/hooks ]
check "project without --apple adds no CODING.md" [ ! -e CODING.md ]
check "project without --apple installs no swift-lsp" [ "$(count swift-lsp)" -eq 0 ]
echo mine > docs/CLAUDE.md
PATH="$fakes:$base" "$src/install.sh" project > "$work/out" 2>&1
check "a second project run keeps an edited template" [ "$(cat docs/CLAUDE.md)" = mine ]
check "a second project run says it kept it" grep -q "kept docs/CLAUDE.md" "$work/out"

# project --apple
mkdir -p "$work/p2" && cd "$work/p2" && git init -q || exit 1
PATH="$fakes:$base" "$src/install.sh" project --apple > "$work/out" 2>&1
check "project --apple succeeds" [ $? -eq 0 ]
check "project --apple adds CODING.md" [ -f CODING.md ]
check "project --apple adds the code smells" [ -f docs/code-smells.md ]
check "project --apple's CLAUDE.md imports all four" \
    [ "$(cat CLAUDE.md)" = "$(printf '@CONTRIBUTING.md\n@CODING.md\n@docs/CLAUDE.md\n@docs/code-smells.md')" ]
check "project --apple installs swift-lsp once" [ "$(count "plugin install swift-lsp@claude-plugins-official")" -eq 1 ]
for p in swift-concurrency-pro@swift-concurrency-agent-skill swiftui-pro@swiftui-agent-skill \
    swift-testing-pro@swift-testing-agent-skill; do
    check "project --apple installs $p" [ "$(count "plugin install $p")" -eq 1 ]
done
PATH="$fakes:$base" "$src/install.sh" project --apple > "$work/out" 2>&1
check "a second project --apple run doesn't install swift-lsp again" [ "$(count "plugin install swift-lsp")" -eq 1 ]
check "a second project --apple run doesn't install the Swift skills again" [ "$(count "plugin install swift")" -eq 4 ]

# project --apple under a folder whose CLAUDE.md already holds the code smells, which Claude Code loads too
mkdir -p "$work/apps/p4" && cp "$src/apple/CLAUDE.md" "$work/apps/CLAUDE.md" && cd "$work/apps/p4" && git init -q || exit 1
PATH="$fakes:$base" "$src/install.sh" project --apple > "$work/out" 2>&1
check "project --apple under the code smells succeeds" [ $? -eq 0 ]
check "project --apple under the code smells doesn't copy them" [ ! -e docs/code-smells.md ]
check "project --apple under the code smells says where they are" grep -q "$work/apps/CLAUDE.md" "$work/out"
check "project --apple under the code smells imports three" \
    [ "$(cat CLAUDE.md)" = "$(printf '@CONTRIBUTING.md\n@CODING.md\n@docs/CLAUDE.md')" ]

# A CLAUDE.md of the project's own is never rewritten; it says what to add
mkdir -p "$work/p3" && cd "$work/p3" && git init -q && echo "# our rules" > CLAUDE.md || exit 1
echo "*.png binary" > .gitattributes
PATH="$fakes:$base" "$src/install.sh" project > "$work/out" 2>&1
check "an existing CLAUDE.md is left as it was" [ "$(cat CLAUDE.md)" = "# our rules" ]
check "it lists the imports to add" grep -q "@docs/CLAUDE.md" "$work/out"
check "an existing .gitattributes is left as it was" [ "$(cat .gitattributes)" = "*.png binary" ]
check "it gives the union line to add" grep -qF "  docs/decisions.md merge=union" "$work/out"
echo "docs/decisions.md merge=union" >> .gitattributes
PATH="$fakes:$base" "$src/install.sh" project > "$work/out" 2>&1
check "with the union line there, it doesn't ask for it" sh -c "! grep -q 'merge=union' '$work/out'"

# Not a git repository yet, and a hooksPath of the project's own
mkdir -p "$work/p4" && cd "$work/p4" || exit 1
PATH="$fakes:$base" "$src/install.sh" project > "$work/out" 2>&1
check "a folder without git still succeeds" [ $? -eq 0 ]
check "a folder without git still gets the templates" [ -f docs/CLAUDE.md ]
check "it says to set core.hooksPath after git init" grep -q "after git init" "$work/out"
mkdir -p "$work/p5" && cd "$work/p5" && git init -q && git config core.hooksPath .githooks || exit 1
PATH="$fakes:$base" "$src/install.sh" project > "$work/out" 2>&1
check "a hooksPath of the project's own is kept" [ "$(git config core.hooksPath)" = .githooks ]

# Refusals
mkdir -p "$work/p1/sub" && cd "$work/p1/sub" && PATH="$fakes:$base" "$src/install.sh" project > "$work/out" 2>&1
check "project in a repository's subfolder fails" [ $? -eq 1 ]
check "project in a repository's subfolder adds nothing" [ ! -e "$work/p1/sub/docs" ]
cd "$work/p1" && PATH="$fakes:$base" "$src/install.sh" project --bogus > "$work/out" 2>&1
check "project with an unknown option exits 2" [ $? -eq 2 ]
cd "$src" && PATH="$fakes:$base" "$src/install.sh" project > "$work/out" 2>&1
check "project in the workflow's own clone fails" [ $? -eq 1 ]
check "project in the workflow's own clone adds nothing" [ ! -e "$src/CONTRIBUTING.md" ]

[ "$failures" -eq 0 ] && echo "all passed" || { echo "$failures failed"; exit 1; }
