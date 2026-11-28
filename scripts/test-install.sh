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
# From here, git reads none of the maintainer's config: no global or system file, no global excludes.
mkdir -p "$work/xdg" && : > "$work/gitconfig" || exit 1
export GIT_CONFIG_GLOBAL="$work/gitconfig" XDG_CONFIG_HOME="$work/xdg" GIT_CONFIG_NOSYSTEM=1
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
# The files a project's AGENTS.md lists to read, and the lines its CLAUDE.md imports.
reads() { sed -n 's/^- `\([^`]*\)`.*/\1/p' AGENTS.md; }
imports() { grep '^@' CLAUDE.md; }
base="/usr/bin:/bin"

# From a clone, with an old CLAUDE.md in place
fresh one && mkdir -p "$HOME/.claude" && echo old > "$HOME/.claude/CLAUDE.md" && echo mine > "$HOME/.claude/AGENTS.md"
PATH="$fakes:$HOME/.local/bin:$base" "$src/install.sh" > "$work/out" 2>&1
check "first run succeeds" [ $? -eq 0 ]
check "CLAUDE.md links to the clone" [ "$(readlink "$HOME/.claude/CLAUDE.md")" = "$src/core/global/CLAUDE.md" ]
check "the old CLAUDE.md is kept as a backup" sh -c "cat '$HOME'/.claude/CLAUDE.md.backup.* | grep -qx old"
check "an AGENTS.md of the user's own beside CLAUDE.md is kept" [ "$(cat "$HOME/.claude/AGENTS.md")" = mine ]
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
check "piped run clones to ~/.agent-workflow" [ -f "$HOME/.agent-workflow/core/global/CLAUDE.md" ]
check "piped run links CLAUDE.md into that clone" [ "$(readlink "$HOME/.claude/CLAUDE.md")" = "$HOME/.agent-workflow/core/global/CLAUDE.md" ]
check "piped run warns that ~/.local/bin isn't on the PATH" grep -q "add ~/.local/bin to your PATH" "$work/out"
echo new > "$src/new-file" && git -C "$src" add new-file && git -C "$src" -c user.name=t -c user.email=t@t commit -qm new
PATH="$fakes:$base" "$HOME/.local/bin/agent-workflow" > "$work/out" 2>&1
check "a later run pulls the clone" [ -f "$HOME/.agent-workflow/new-file" ]

# A clone from before the rename, at ~/.claude-workflow, run through its old command: it moves to ~/.agent-workflow
fresh six && git clone -q "$src" "$HOME/.claude-workflow" && mkdir -p "$HOME/.claude" "$HOME/.local/bin" || exit 1
ln -s "$HOME/.claude-workflow/core/global/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
ln -s "$HOME/.claude-workflow/install.sh" "$HOME/.local/bin/claude-workflow"
AGENT_WORKFLOW_REPO_URL="$src" PATH="$fakes:$base" "$HOME/.local/bin/claude-workflow" > "$work/out" 2>&1
check "an old clone's run succeeds" [ $? -eq 0 ]
check "the old clone moves to ~/.agent-workflow" [ -f "$HOME/.agent-workflow/core/global/CLAUDE.md" ]
check "the old clone is gone from ~/.claude-workflow" [ ! -e "$HOME/.claude-workflow" ]
check "it says it moved the clone" grep -q "moved $HOME/.claude-workflow to" "$work/out"
check "CLAUDE.md links into the moved clone" [ "$(readlink "$HOME/.claude/CLAUDE.md")" = "$HOME/.agent-workflow/core/global/CLAUDE.md" ]
check "agent-workflow links into the moved clone" [ "$(readlink "$HOME/.local/bin/agent-workflow")" = "$HOME/.agent-workflow/install.sh" ]
check "the old claude-workflow command is gone" [ ! -L "$HOME/.local/bin/claude-workflow" ]

# Both clones there: nothing is moved, and it says so
fresh seven && git clone -q "$src" "$HOME/.claude-workflow" && git clone -q "$src" "$HOME/.agent-workflow" || exit 1
AGENT_WORKFLOW_REPO_URL="$src" PATH="$fakes:$base" "$HOME/.claude-workflow/install.sh" > "$work/out" 2>&1
check "with both clones, the run succeeds" [ $? -eq 0 ]
check "with both clones, the old one stays" [ -d "$HOME/.claude-workflow/.git" ]
check "with both clones, the new one stays" [ -d "$HOME/.agent-workflow/.git" ]
check "with both clones, it says it left the old one" grep -q "left $HOME/.claude-workflow as it is" "$work/out"

# A link from before the global instructions were split, to core/CLAUDE.md, which now only forwards to
# core/global/CLAUDE.md, so it still loads the global rules until it's made again
fresh eight && mkdir -p "$HOME/.claude" && ln -s "$src/core/CLAUDE.md" "$HOME/.claude/CLAUDE.md" || exit 1
# An AGENTS.md link beside it, from before CLAUDE.md's import was known to resolve from the link's target
ln -s "$src/core/global/AGENTS.md" "$HOME/.claude/AGENTS.md" || exit 1
PATH="$fakes:$base" "$src/install.sh" > "$work/out" 2>&1
check "core/CLAUDE.md forwards to the global instructions" sh -c "[ \"\$(grep '^@' '$src/core/CLAUDE.md')\" = @global/CLAUDE.md ] && [ -f '$src/core/global/CLAUDE.md' ]"
check "a link from before the split is made again" [ "$(readlink "$HOME/.claude/CLAUDE.md")" = "$src/core/global/CLAUDE.md" ]
check "an AGENTS.md link into the clone is removed" sh -c "[ ! -e '$HOME/.claude/AGENTS.md' ] && [ ! -L '$HOME/.claude/AGENTS.md' ]"

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
for f in AGENTS.md docs/principles.md CONTRIBUTING.md scripts/hooks/commit-msg scripts/hooks/pre-commit \
    scripts/hooks/checks.sh scripts/hooks/scrub.sh .claude/agents/code-reviewer.md \
    .github/workflows/review.yml .github/pull_request_template.md \
    docs/templates/spec.md docs/templates/decisions.md docs/templates/edge-list.md .agents/skills/README.md; do
    check "project adds $f" [ -f "$f" ]
done
check "project links .claude/skills to .agents/skills" [ "$(readlink .claude/skills)" = ../.agents/skills ]
check "the .claude/skills link resolves" [ -f .claude/skills/README.md ]
check "project's .gitattributes merges the decisions log with union" grep -qxF "docs/decisions.md merge=union" .gitattributes
check "project adds no decisions log of its own" [ ! -e docs/decisions.md ]
check "project with public notes leaves .gitignore alone" [ ! -e .gitignore ]
check "project's AGENTS.md lists CONTRIBUTING.md and docs/principles.md to read" \
    [ "$(reads)" = "$(printf 'CONTRIBUTING.md\ndocs/principles.md')" ]
check "project's AGENTS.md has no marker left" sh -c "! grep -q 'files to read' AGENTS.md"
check "project's CLAUDE.md imports AGENTS.md, then CONTRIBUTING.md and docs/principles.md" \
    [ "$(imports)" = "$(printf '@AGENTS.md\n@CONTRIBUTING.md\n@docs/principles.md')" ]
check "project: adds the hooks" sh -c "[ -x scripts/hooks/commit-msg ] && [ -x scripts/hooks/pre-commit ] && [ -x scripts/hooks/scrub.sh ] && cmp -s scripts/hooks/checks.sh '$src/core/hooks/checks.sh'"
check "project: adds CODEOWNERS" cmp -s .github/CODEOWNERS "$src/core/github/CODEOWNERS"
check "project: adds settings.json with the hook" sh -c "cmp -s .claude/settings.json '$src/core/claude/settings.json' && [ -x .claude/hooks/protected-edit.sh ]"
check "project: says how to make the scrub list" grep -qF ".git/info/scrub-words" "$work/out"
check "project: adds the CI checks" sh -c "[ -x scripts/ci-checks.sh ] && cmp -s .github/workflows/checks.yml '$src/core/github/checks.yml'"
check "a new project's hooks get no warning that they differ" sh -c "! grep -q 'differs' '$work/out'"
check "project sets core.hooksPath" [ "$(git config core.hooksPath)" = scripts/hooks ]
check "project without --apple adds no CODING.md" [ ! -e CODING.md ]
check "project without --apple installs no swift-lsp" [ "$(count swift-lsp)" -eq 0 ]
check "project without --apple adds no Swift configs" sh -c "[ ! -e .swift-format ] && [ ! -e .swiftlint.yml ]"
check "project with the template's CONTRIBUTING.md doesn't warn about its types" sh -c "! grep -q 'Types:' '$work/out'"
echo mine > docs/principles.md
PATH="$fakes:$base" "$src/install.sh" project > "$work/out" 2>&1
check "a second project run keeps an edited template" [ "$(cat docs/principles.md)" = mine ]
check "a second project run says it kept it" grep -q "kept docs/principles.md" "$work/out"
check "a second project run keeps the skills link" [ "$(readlink .claude/skills)" = ../.agents/skills ]
check "a second project run says nothing about the skills link" sh -c "! grep -q 'claude/skills' '$work/out'"

# project --apple
mkdir -p "$work/p2" && cd "$work/p2" && git init -q || exit 1
PATH="$fakes:$base" "$src/install.sh" project --apple > "$work/out" 2>&1
check "project --apple succeeds" [ $? -eq 0 ]
check "project --apple adds CODING.md" [ -f CODING.md ]
check "project --apple adds the code smells" [ -f docs/code-smells.md ]
check "project --apple adds .swift-format and .swiftlint.yml" \
    sh -c "cmp -s .swift-format '$src/apple/swift-format.json' && cmp -s .swiftlint.yml '$src/apple/swiftlint.yml'"
check "project --apple's AGENTS.md lists all four to read" \
    [ "$(reads)" = "$(printf 'CONTRIBUTING.md\nCODING.md\ndocs/principles.md\ndocs/code-smells.md')" ]
check "project --apple's CLAUDE.md imports AGENTS.md and all four" \
    [ "$(imports)" = "$(printf '@AGENTS.md\n@CONTRIBUTING.md\n@CODING.md\n@docs/principles.md\n@docs/code-smells.md')" ]
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
check "project --apple under the code smells imports AGENTS.md and three" \
    [ "$(imports)" = "$(printf '@AGENTS.md\n@CONTRIBUTING.md\n@CODING.md\n@docs/principles.md')" ]
check "project --apple under the code smells lists three to read" \
    [ "$(reads)" = "$(printf 'CONTRIBUTING.md\nCODING.md\ndocs/principles.md')" ]

# A CLAUDE.md of the project's own is never rewritten; it says what to add
mkdir -p "$work/p3" && cd "$work/p3" && git init -q && echo "# our rules" > CLAUDE.md || exit 1
echo "*.png binary" > .gitattributes
mkdir -p .claude/skills/ours
PATH="$fakes:$base" "$src/install.sh" project > "$work/out" 2>&1
check "an existing CLAUDE.md is left as it was" [ "$(cat CLAUDE.md)" = "# our rules" ]
check "it lists the imports to add" grep -q "@docs/principles.md" "$work/out"
check "it lists AGENTS.md among the imports to add" grep -qx "  @AGENTS.md" "$work/out"
check "an existing .gitattributes is left as it was" [ "$(cat .gitattributes)" = "*.png binary" ]
check "it gives the union line to add" grep -qF "  docs/decisions.md merge=union" "$work/out"
check "a .claude/skills folder of the project's own is kept" sh -c "[ -d .claude/skills/ours ] && [ ! -L .claude/skills ]"
check "it says how to link .claude/skills instead" grep -qF "ln -s ../.agents/skills .claude/skills" "$work/out"
echo "docs/decisions.md merge=union" >> .gitattributes
PATH="$fakes:$base" "$src/install.sh" project > "$work/out" 2>&1
check "with the union line there, it doesn't ask for it" sh -c "! grep -q 'merge=union' '$work/out'"

# An AGENTS.md of the project's own is never rewritten; it says which files to add to its list
mkdir -p "$work/p6" && cd "$work/p6" && git init -q && printf '# ours\n\nRead `CONTRIBUTING.md` first.\n' > AGENTS.md || exit 1
PATH="$fakes:$base" "$src/install.sh" project > "$work/out" 2>&1
check "an existing AGENTS.md is left as it was" [ "$(cat AGENTS.md)" = "$(printf '# ours\n\nRead `CONTRIBUTING.md` first.')" ]
check "it lists the file AGENTS.md doesn't name" grep -qx "  docs/principles.md" "$work/out"
check "it doesn't list the file AGENTS.md names" sh -c "! grep -qx '  CONTRIBUTING.md' '$work/out'"
check "a project with its own AGENTS.md still gets a CLAUDE.md that imports it" [ "$(head -1 CLAUDE.md)" = @AGENTS.md ]

# A project set up before the rename has the principles as docs/CLAUDE.md: it says how to rename them, and doesn't copy them twice
mkdir -p "$work/p7/docs" && cd "$work/p7" && git init -q && cp "$src/core/principles.md" docs/CLAUDE.md || exit 1
printf '@CONTRIBUTING.md\n@docs/CLAUDE.md\n' > CLAUDE.md
PATH="$fakes:$base" "$src/install.sh" project > "$work/out" 2>&1
check "an old docs/CLAUDE.md with the principles is left as it was" cmp -s docs/CLAUDE.md "$src/core/principles.md"
check "the principles aren't copied a second time" [ ! -e docs/principles.md ]
check "it says how to rename the old copy" grep -qF "git mv docs/CLAUDE.md docs/principles.md" "$work/out"
check "it doesn't also ask for an import the rename gives" sh -c "! grep -qx '  @docs/principles.md' '$work/out'"
check "it says how to get the principles if the old file isn't them" grep -qF "copy $src/core/principles.md to docs/principles.md" "$work/out"
# A docs/CLAUDE.md with its own first line may still be an adapted copy, so the principles aren't added beside it either
mkdir -p "$work/p8/docs" && cd "$work/p8" && git init -q && echo "# Our app: notes for AI agents" > docs/CLAUDE.md || exit 1
PATH="$fakes:$base" "$src/install.sh" project > "$work/out" 2>&1
check "an adapted docs/CLAUDE.md is left as it was" [ "$(cat docs/CLAUDE.md)" = "# Our app: notes for AI agents" ]
check "an adapted docs/CLAUDE.md doesn't get the principles beside it" [ ! -e docs/principles.md ]
check "it says how to rename an adapted copy" grep -qF "git mv docs/CLAUDE.md docs/principles.md" "$work/out"

# Private notes: docs/ is git-ignored, so AGENTS.md and CLAUDE.md, which name files in it, are ignored too
mkdir -p "$work/p9" && cd "$work/p9" && git init -q && printf '/docs/' > .gitignore || exit 1
PATH="$fakes:$base" "$src/install.sh" project > "$work/out" 2>&1
check "private notes: project succeeds" [ $? -eq 0 ]
check "private notes: AGENTS.md is git-ignored" git check-ignore -q AGENTS.md
check "private notes: CLAUDE.md is git-ignored" git check-ignore -q CLAUDE.md
check "private notes: the old last line of .gitignore stays whole" [ "$(head -1 .gitignore)" = /docs/ ]
check "private notes: the union line goes in docs/, beside the log" grep -qxF "decisions.md merge=union" docs/.gitattributes
check "private notes: no .gitattributes at the root" [ ! -e .gitattributes ]
lines="$(wc -l < .gitignore)"
PATH="$fakes:$base" "$src/install.sh" project > "$work/out" 2>&1
check "private notes: a second run adds nothing to .gitignore" [ "$(wc -l < .gitignore)" -eq "$lines" ]
# Private notes found by docs/ being a repository of its own, before it's ignored
mkdir -p "$work/p10/docs" && cd "$work/p10" && git init -q && git -C docs init -q || exit 1
PATH="$fakes:$base" "$src/install.sh" project > "$work/out" 2>&1
check "notes in a repository of their own: AGENTS.md is git-ignored" git check-ignore -q AGENTS.md
check "project: appends /docs/ for a docs repository" grep -qxF /docs/ .gitignore
# The same before git init: a second run still adds nothing to .gitignore
mkdir -p "$work/p12/docs" && cd "$work/p12" && git -C docs init -q || exit 1
PATH="$fakes:$base" "$src/install.sh" project > "$work/out" 2>&1
lines="$(wc -l < .gitignore)"
PATH="$fakes:$base" "$src/install.sh" project > "$work/out" 2>&1
check "notes in a repository of their own, no git yet: a second run adds nothing to .gitignore" [ "$(wc -l < .gitignore)" -eq "$lines" ]
# Private notes with a tracked AGENTS.md, and a root .gitattributes from when they were public: it says to
# untrack AGENTS.md before it lists what to add, and to remove the old union line
mkdir -p "$work/p11" && cd "$work/p11" && git init -q && printf '/docs/\n' > .gitignore && echo "# ours" > AGENTS.md && git add AGENTS.md || exit 1
echo "docs/decisions.md merge=union" > .gitattributes
PATH="$fakes:$base" "$src/install.sh" project > "$work/out" 2>&1
check "a tracked AGENTS.md with private notes is left as it was" [ "$(cat AGENTS.md)" = "# ours" ]
check "it says to untrack AGENTS.md" grep -qF "git rm --cached AGENTS.md" "$work/out"
check "it says to untrack AGENTS.md before it lists what to add" sh -c "u=\$(grep -n 'git rm --cached AGENTS.md' '$work/out' | cut -d: -f1); a=\$(grep -n 'add these to the files' '$work/out' | cut -d: -f1); [ -n \"\$u\" ] && [ -n \"\$a\" ] && [ \"\$u\" -lt \"\$a\" ]"
check "it says to remove the old union line from the root .gitattributes" grep -qF "remove its line docs/decisions.md merge=union" "$work/out"
lines="$(wc -l < .gitignore)"
PATH="$fakes:$base" "$src/install.sh" project > "$work/out" 2>&1
check "with AGENTS.md still tracked, a second run adds nothing to .gitignore" [ "$(wc -l < .gitignore)" -eq "$lines" ]

# A CONTRIBUTING.md of the project's own without a Types line is kept, with a warning: commit-msg refuses every commit
mkdir -p "$work/p13" && cd "$work/p13" && git init -q && echo '# How we work' > CONTRIBUTING.md || exit 1
PATH="$fakes:$base" "$src/install.sh" project > "$work/out" 2>&1
check "project: keeps a CONTRIBUTING.md without a Types line" [ "$(cat CONTRIBUTING.md)" = '# How we work' ]
check "project: warns when CONTRIBUTING.md has no Types line" grep -q 'Types:' "$work/out"

# Private notes with a docs/ file tracked: still private
mkdir -p "$work/p14/docs" && cd "$work/p14" && git init -q && printf '/docs/\n' > .gitignore && echo x > docs/x.md &&
    git add -f docs/x.md || exit 1
PATH="$fakes:$base" "$src/install.sh" project > "$work/out" 2>&1
check "project: private notes with a docs/ file tracked" grep -qxF /AGENTS.md .gitignore

# Notes ignored only by a local rule: /docs/ goes in .gitignore too, since CI and worktrees read only that
mkdir -p "$work/p23/docs" && cd "$work/p23" && git init -q && echo /docs/ > .git/info/exclude || exit 1
PATH="$fakes:$base" "$src/install.sh" project > "$work/out" 2>&1
check "project: appends /docs/ when only a local rule ignores it" grep -qxF /docs/ .gitignore

# A CODEOWNERS of the project's own is kept, and the template's lines printed: a second one would win over it
mkdir -p "$work/p17" && cd "$work/p17" && git init -q && printf '/src/ @us\n/.gitignore @us\n' > CODEOWNERS || exit 1
PATH="$fakes:$base" "$src/install.sh" project > "$work/out" 2>&1
check "project: keeps a root CODEOWNERS" sh -c "[ ! -e .github/CODEOWNERS ] && [ \"\$(cat CODEOWNERS)\" = \"\$(printf '/src/ @us\n/.gitignore @us')\" ]"
check "project: prints the template's lines to add" grep -qx '  /scripts/hooks/ @OWNER' "$work/out"
check "project: names the CODEOWNERS it uses" sh -c "grep -qx '  /CODEOWNERS @OWNER' '$work/out' && ! grep -q '/.github/CODEOWNERS @OWNER' '$work/out'"
check "project: doesn't print a line the file has" sh -c "! grep -qx '  /.gitignore @OWNER' '$work/out'"
check "project: no warning without a catch-all line" sh -c "! grep -q 'catch-all' '$work/out'"
check "project without --apple with its own CODEOWNERS isn't told the Swift configs" sh -c "! grep -q 'swift' '$work/out'"
# The same with --apple: told the Swift configs' lines too, and a .swiftlint.yml of its own kept
mkdir -p "$work/p24" && cd "$work/p24" && git init -q && printf '/src/ @us\n' > CODEOWNERS && echo mine > .swiftlint.yml || exit 1
PATH="$fakes:$base" "$src/install.sh" project --apple > "$work/out" 2>&1
check "project --apple with its own CODEOWNERS is told /.swiftlint.yml and /.swift-format" \
    sh -c "grep -qx '  /.swiftlint.yml @OWNER' '$work/out' && grep -qx '  /.swift-format @OWNER' '$work/out'"
check "project --apple keeps its own .swiftlint.yml" [ "$(cat .swiftlint.yml)" = mine ]
mkdir -p "$work/p18" && cd "$work/p18" && git init -q && printf '* @us\n' > CODEOWNERS || exit 1
PATH="$fakes:$base" "$src/install.sh" project > "$work/out" 2>&1
check "project: warns about a catch-all line" grep -q 'catch-all' "$work/out"

# Claude's hook: settings.json is written when there's none; one of the project's own is kept, and the hook block
# printed unless it already names the hook.
mkdir -p "$work/p19/.claude" && cd "$work/p19" && git init -q && printf '{"model":"x"}\n' > .claude/settings.json || exit 1
PATH="$fakes:$base" "$src/install.sh" project > "$work/out" 2>&1
check "project: keeps settings.json" sh -c "[ \"\$(cat .claude/settings.json)\" = '{\"model\":\"x\"}' ] && grep -q 'protected-edit.sh' '$work/out'"
mkdir -p "$work/p20/.claude" && cd "$work/p20" && git init -q && cp "$src/core/claude/settings.json" .claude/ || exit 1
PATH="$fakes:$base" "$src/install.sh" project > "$work/out" 2>&1
check "project: no block when the hook is named" sh -c "! grep -q 'settings.json is already there' '$work/out'"

mkdir -p "$work/p21/.github/workflows" && cd "$work/p21" && git init -q && echo 'name: ours' > .github/workflows/checks.yml || exit 1
PATH="$fakes:$base" "$src/install.sh" project > "$work/out" 2>&1
check "project: warns about an older checks.yml" grep -q '.github/workflows/checks.yml differs' "$work/out"

# A private-notes project's whole install output goes through its own hooks: no installed text points into the notes
mkdir -p "$work/p22" && cd "$work/p22" && git init -q && git symbolic-ref HEAD refs/heads/feat && printf '/docs/\n' > .gitignore &&
    echo Secretname > .git/info/scrub-words || exit 1
PATH="$fakes:$base" "$src/install.sh" project > "$work/out" 2>&1
git add -A && git -c user.name=t -c user.email=t@t commit -qm 'chore: set up agent-workflow' > "$work/out" 2>&1
check "project: a private-notes project commits its install output" [ $? -eq 0 ]

# Hooks kept from an older setup: a warning when one differs, except in commit-msg's ALLOW_AI_CREDIT line
mkdir -p "$work/p15/scripts/hooks" && cd "$work/p15" && git init -q && printf '#!/bin/sh\nexit 0\n' > scripts/hooks/commit-msg || exit 1
PATH="$fakes:$base" "$src/install.sh" project > "$work/out" 2>&1
check "project: keeps an older hook" [ "$(cat scripts/hooks/commit-msg)" = "$(printf '#!/bin/sh\nexit 0')" ]
check "project: warns about an older hook" grep -q 'scripts/hooks/commit-msg differs' "$work/out"
check "project: no checks.yml while the hooks are older" sh -c "[ ! -e .github/workflows/checks.yml ] && grep -q 'checks.yml.*commit-msg' '$work/out'"
mkdir -p "$work/p16/scripts/hooks" && cd "$work/p16" && git init -q &&
    sed 's/^ALLOW_AI_CREDIT=1$/ALLOW_AI_CREDIT=0/' "$src/core/hooks/commit-msg" > scripts/hooks/commit-msg || exit 1
PATH="$fakes:$base" "$src/install.sh" project > "$work/out" 2>&1
check "project: ALLOW_AI_CREDIT doesn't count" sh -c "grep -q '^ALLOW_AI_CREDIT=0' scripts/hooks/commit-msg && ! grep -q 'differs' '$work/out'"
check "project: checks.yml with hooks that know CI" [ -f .github/workflows/checks.yml ]

# Not a git repository yet, and a hooksPath of the project's own
mkdir -p "$work/p4" && cd "$work/p4" || exit 1
PATH="$fakes:$base" "$src/install.sh" project > "$work/out" 2>&1
check "a folder without git still succeeds" [ $? -eq 0 ]
check "a folder without git still gets the templates" [ -f docs/principles.md ]
check "it says to set core.hooksPath after git init" grep -q "after git init" "$work/out"
mkdir -p "$work/p5" && cd "$work/p5" && git init -q && git config core.hooksPath .githooks || exit 1
PATH="$fakes:$base" "$src/install.sh" project > "$work/out" 2>&1
check "a hooksPath of the project's own is kept" [ "$(git config core.hooksPath)" = .githooks ]
check "project: names every hook to move" sh -c "grep 'core.hooksPath is already' '$work/out' | grep 'commit-msg' | grep 'pre-commit' | grep 'checks.sh' | grep -q 'scrub.sh'"

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
