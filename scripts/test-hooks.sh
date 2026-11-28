#!/bin/sh
# Runs the hooks against messages and staged changes that must pass or be refused.
# Usage: scripts/test-hooks.sh (from anywhere in the repository). SH=dash runs the hooks under dash.

root="$(git rev-parse --show-toplevel)" || exit 1
mkdir -p "$root/build" && work="$(mktemp -d "$root/build/test-hooks.XXXXXX")" || exit 1
trap 'rm -rf "$work"' EXIT
failures=0

# The fixtures read none of the maintainer's git config: no global or system file, no global excludes.
mkdir -p "$work/xdg" && : > "$work/gitconfig" || exit 1
export GIT_CONFIG_GLOBAL="$work/gitconfig" XDG_CONFIG_HOME="$work/xdg" GIT_CONFIG_NOSYSTEM=1
git config --global user.name t && git config --global user.email t@t || exit 1

# expect [-m <pattern> | -n <pattern>] pass|refuse <name> <command...>
# With -m the command's stderr must match the pattern (grep's basic syntax); with -n it mustn't.
expect() {
    match="" nomatch=""
    case "$1" in
        -m) match="$2" && shift 2 ;;
        -n) nomatch="$2" && shift 2 ;;
    esac
    want="$1" name="$2"
    shift 2
    if "$@" >/dev/null 2>"$work/stderr"; then got=pass; else got=refuse; fi
    why=""
    [ "$got" = "$want" ] || why="wanted $want, got $got"
    [ -n "$match" ] && ! grep -q -- "$match" "$work/stderr" && why="${why:+$why; }stderr doesn't match $match"
    [ -n "$nomatch" ] && grep -q -- "$nomatch" "$work/stderr" && why="${why:+$why; }stderr matches $nomatch"
    if [ -z "$why" ]; then echo "ok    $name"; else echo "FAIL  $name ($why)"; failures=$((failures + 1)); fi
}

message() { printf "$1" > "$work/msg"; }

# fixture <folder>: a repository on the branch feat, with a scrub list and core/CONTRIBUTING.md staged,
# so no test passes because of a refusal it isn't about.
fixture() {
    git init -q "$1" && git -C "$1" symbolic-ref HEAD refs/heads/feat &&
        printf 'Secretname\n' > "$1/.git/info/scrub-words" &&
        cp "$root/core/CONTRIBUTING.md" "$1/" && git -C "$1" add CONTRIBUTING.md || exit 1
}

# commit_msg <repository> [hook]: runs the commit-msg hook (core's by default) on $work/msg, as git would.
# Git hands hooks GIT_EDITOR, ":" when no editor ran (-m, -F); these run as if one had.
commit_msg() { (cd "$1" && GIT_EDITOR=vi ${SH:-sh} "${2:-$hook}" "$work/msg"); }

# core/hooks/commit-msg, in a repository with the template's CONTRIBUTING.md
hook="$root/core/hooks/commit-msg"
cm="$work/cm" && fixture "$cm"
message 'feat(sync): keep the draft\n';                 expect pass   "conventional subject" commit_msg "$cm"
message 'fix!: drop the old format\n';                  expect pass   "breaking change without a scope" commit_msg "$cm"
message 'fixup! feat(sync): keep the draft\n';          expect pass   "fixup subject" commit_msg "$cm"
message 'Merge pull request #1 from a/b\n';             expect pass   "merge subject" commit_msg "$cm"
message 'Keep the draft\n';                             expect refuse "no type" commit_msg "$cm"
message 'feature: keep the draft\n';                    expect refuse "unknown type" commit_msg "$cm"
message 'fix: keep the draft.\n';                       expect refuse "full stop" commit_msg "$cm"
message "fix: $(printf '%0101d' 0 | tr 0 a)\n";         expect refuse "subject over 100 characters" commit_msg "$cm"
message "fix: $(printf '%080d' 0 | tr 0 a)\n";          expect pass   "subject over 72 only warns" commit_msg "$cm"
message 'fix: x\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>\n'; expect pass "AI co-author, allowed by default" commit_msg "$cm"
message 'fix: x\n\nCo-Authored-By: Sam <a@b.c>\n';      expect pass   "human co-author" commit_msg "$cm"
message '\n# only comments\n';                          expect refuse "empty message" commit_msg "$cm"

# The types and scopes come from the staged CONTRIBUTING.md
message 'feature: x\n'
expect -m 'one of: feat fix test refactor perf docs style build ci chore$' refuse "types: the template lists today's ten" commit_msg "$cm"
message 'feat(anything): x\n';                          expect pass   "scopes: core/CONTRIBUTING.md allows any" commit_msg "$cm"
own="$work/own" && fixture "$own"
sed -e '/^- \*\*Types:\*\*/s/`perf`, /`wip`, /' \
    -e '/^- \*\*Scopes:\*\*/s/<!--.*-->/`sync` (the sync engine), `ui` <!-- `old` was split into these two -->/' \
    "$root/core/CONTRIBUTING.md" > "$own/CONTRIBUTING.md" && git -C "$own" add CONTRIBUTING.md || exit 1
message 'wip: x\n';                                     expect pass   "types: a type only CONTRIBUTING.md lists" commit_msg "$own"
message 'perf: x\n'
expect -m 'one of: feat fix test refactor wip docs style build ci chore$' refuse "types: a type CONTRIBUTING.md leaves out" commit_msg "$own"
message 'feat(sync): x\n';                              expect pass   "scopes: a listed scope" commit_msg "$own"
message 'feat(core): x\n';                              expect -m '"core"' refuse "scopes: an unlisted scope" commit_msg "$own"
message 'feat(old): x\n';                               expect -m '"old"' refuse "scopes: names in a comment don't count" commit_msg "$own"
# HEAD and the working tree have the scopes above; only the staged copy adds new.
git -C "$own" commit -qm init && sed 's/`sync` (/`new`, `sync` (/' "$own/CONTRIBUTING.md" > "$work/c" &&
    cp "$work/c" "$own/CONTRIBUTING.md" && git -C "$own" add CONTRIBUTING.md &&
    git -C "$own" show HEAD:CONTRIBUTING.md > "$own/CONTRIBUTING.md" || exit 1
message 'feat(new): x\n';                               expect pass   "scopes: a scope added in the same commit" commit_msg "$own"
notypes="$work/notypes" && fixture "$notypes"
grep -v '^- \*\*Types:\*\*' "$root/core/CONTRIBUTING.md" > "$notypes/CONTRIBUTING.md" && git -C "$notypes" add CONTRIBUTING.md || exit 1
message 'feat: x\n';                                    expect -m 'Types:' refuse "types: no Types line" commit_msg "$notypes"
# The working tree keeps its copy; only the index counts.
nofile="$work/nofile" && fixture "$nofile" && git -C "$nofile" rm -q --cached CONTRIBUTING.md || exit 1
message 'feat: x\n';                                    expect -m 'no CONTRIBUTING.md' refuse "types: no CONTRIBUTING.md" commit_msg "$nofile"

# The same hook with AI credit refused, beside the files it sources
mkdir -p "$work/refused" && cp "$root/core/hooks/checks.sh" "$root/core/hooks/scrub.sh" "$work/refused/" &&
    sed 's/^ALLOW_AI_CREDIT=1$/ALLOW_AI_CREDIT=0/' "$hook" > "$work/refused/commit-msg" || exit 1
refused="$work/refused/commit-msg"
grep -q '^ALLOW_AI_CREDIT=0$' "$refused" || { echo "FAIL  could not switch AI credit off"; exit 1; }
message 'fix: x\n\nCo-Authored-By: Claude <a@b.c>\n';   expect refuse "refused: AI co-author" commit_msg "$cm" "$refused"
message 'fix: x\n\n# Generated with a tool\n';          expect refuse "refused: tool credit in a # line" commit_msg "$cm" "$refused"
message 'fix: x\n\nCo-Authored-By: Sam <a@b.c>\n';      expect pass   "refused: human co-author still passes" commit_msg "$cm" "$refused"

# core/hooks/pre-commit. Repositories are set up with commits made without hooks.
pre="$root/core/hooks/pre-commit"
pre_commit() { (cd "$1" && ${SH:-sh} "$pre"); }
# restore <repository>: the index and the tracked files back to HEAD; untracked files stay.
restore() { git -C "$1" reset -q && git -C "$1" checkout -q -- . || exit 1; }

m="$work/main" && fixture "$m" && git -C "$m" symbolic-ref HEAD refs/heads/main || exit 1
expect pass "main: first commit passes" pre_commit "$m"
git -C "$m" commit -qm init && echo x > "$m/a.txt" && git -C "$m" add a.txt || exit 1
expect -m '^pre-commit: .*main' refuse "main: refused" pre_commit "$m"
git -C "$m" checkout -q -b topic && expect pass "main: a branch passes" pre_commit "$m"
git -C "$m" checkout -q --detach && expect pass "main: detached HEAD passes" pre_commit "$m"

# Notes private through the working tree's .gitignore alone, since it isn't committed
pw="$work/pw" && fixture "$pw" && git -C "$pw" commit -qm init && printf '/docs/\n' > "$pw/.gitignore" &&
    mkdir "$pw/docs" && echo x > "$pw/docs/x.md" && echo y > "$pw/docs/y.md" && git -C "$pw" add -f docs/x.md || exit 1
expect -m 'docs/x.md' refuse "private: forced docs/ file" pre_commit "$pw"
git -C "$pw" reset -q && git -C "$pw" add -f docs/y.md && git -C "$pw" commit -qm y && git -C "$pw" add -f docs/x.md || exit 1
expect -m 'docs/x.md' refuse "private: docs/ with a tracked file" pre_commit "$pw"

# Notes private through HEAD's .gitignore
ph="$work/ph" && fixture "$ph" && printf '/docs/\n' > "$ph/.gitignore" && git -C "$ph" add .gitignore &&
    git -C "$ph" commit -qm init && mkdir "$ph/docs" && echo x > "$ph/docs/x.md" || exit 1
: > "$ph/.gitignore" && git -C "$ph" add .gitignore docs/x.md || exit 1
expect -m 'docs/x.md' refuse "private: .gitignore unignores docs/ in the same commit" pre_commit "$ph"
restore "$ph" && : > "$ph/.gitignore" && git -C "$ph" add docs/x.md || exit 1
expect -m 'docs/x.md' refuse "private: .gitignore emptied, unstaged" pre_commit "$ph"
restore "$ph" && echo a > "$ph/AGENTS.md" && git -C "$ph" add AGENTS.md || exit 1
expect -m 'AGENTS.md' refuse "private: AGENTS.md" pre_commit "$ph"
restore "$ph" && echo a > "$ph/CLAUDE.md" && git -C "$ph" add CLAUDE.md || exit 1
expect -m 'CLAUDE.md' refuse "private: CLAUDE.md" pre_commit "$ph"
restore "$ph" && mkdir -p "$ph/sub" && echo a > "$ph/sub/AGENTS.md" && git -C "$ph" add sub/AGENTS.md || exit 1
expect pass "private: nested AGENTS.md passes" pre_commit "$ph"
restore "$ph" && git -C "$ph" add AGENTS.md && git -C "$ph" commit -qm a && git -C "$ph" rm -q --cached AGENTS.md || exit 1
expect pass "private: untracking AGENTS.md passes" pre_commit "$ph"
restore "$ph" && git -C "$ph" add -f docs/x.md && git -C "$ph" commit -qm x && git -C "$ph" rm -q --cached docs/x.md || exit 1
expect pass "private: removing a docs/ file passes" pre_commit "$ph"
# line <file> <text>: the file staged with one line, from HEAD's state
line() { restore "$ph" && mkdir -p "$ph/$(dirname "$1")" && printf '%s\n' "$2" > "$ph/$1" && git -C "$ph" add "$1" || exit 1; }
line a.md 'see docs/plan.md';                           expect -m 'see docs/plan.md' refuse "private: line names docs/" pre_commit "$ph"
line a.md '[plan](../docs/plan.md)';                    expect -m '../docs/plan.md' refuse "private: ../docs/ link" pre_commit "$ph"
line a.md 'kept in sub/docs/ instead';                  expect pass   "private: sub/docs/ passes" pre_commit "$ph"
line .gitignore "$(printf '/docs/\ndocs/')";            expect pass   "private: .gitignore may" pre_commit "$ph"
line a.md 'see https://example.com/docs/a';             expect pass   "private: URL passes" pre_commit "$ph"
line a.md 'see https://example.com/docs/a and docs/b';  expect -m 'and docs/b' refuse "private: URL doesn't exempt the line" pre_commit "$ph"
line a.md 'see docs/plan.md' && printf '* -diff\n' > "$ph/.gitattributes" && git -C "$ph" add .gitattributes || exit 1
expect -m '^see docs/plan.md' refuse "private: -diff doesn't hide lines" pre_commit "$ph"
# The space puts docs/ at a word start in the +++ header, the one place a header could name it.
for t in 'NOTES=docs/plan.md' '--notes=docs/x.md' 'git show HEAD:docs/plan.md' '[a.md,docs/plan.md]' \
    '|[site](https://x.org/a)|[plan](docs/plan.md)|' '<https://x.org/a>docs/plan.md' '[site](https://x.org/a),docs/plan.md'; do
    line a.md "$t" && expect -m 'point into docs/' refuse "private: $t" pre_commit "$ph"
done
line a.md 'see https://x.org/a|b/docs/c';               expect pass   "private: a URL ends at a bar, not inside its own path" pre_commit "$ph"
rm "$ph/.gitattributes" && line 'sub/old docs/a.md' 'x'; expect pass  "private: diff headers aren't lines" pre_commit "$ph"
restore "$ph"
message 'docs: plan\n\nsee docs/plan.md\n';             expect -m 'docs/plan.md' refuse "private: message names docs/" commit_msg "$ph"
message 'chore: untrack the notes\n\n# Changes to be committed:\n#\tdeleted:    docs/x.md\n'
expect pass "private: untracking a docs/ file through the editor passes" commit_msg "$ph"
restore "$ph" && echo z > "$ph/z.txt" && git -C "$ph" add z.txt || exit 1
expect -m '# see docs/plan.md' refuse "private: a # line kept by -m names docs/" \
    git -C "$ph" -c core.hooksPath="$root/core/hooks" commit -q -m 'fix: z' -m '# see docs/plan.md'
restore "$ph"

# docs/ a repository of its own, staged as a gitlink; a docs symlink beside HEAD's /docs/ line
pg="$work/pg" && fixture "$pg" && git -C "$pg" commit -qm init && git init -q "$pg/docs" &&
    git -C "$pg/docs" commit -q --allow-empty -m notes && git -C "$pg" add docs 2>/dev/null || exit 1
expect -m 'unstage: docs ' refuse "private: docs/ gitlink" pre_commit "$pg"
ps="$work/ps" && fixture "$ps" && printf '/docs/\n' > "$ps/.gitignore" && git -C "$ps" add .gitignore &&
    git -C "$ps" commit -qm init && mkdir "$ps/real" && ln -s real "$ps/docs" && git -C "$ps" add docs || exit 1
expect -m 'unstage: docs ' refuse "private: docs symlink" pre_commit "$ps"
pf="$work/pf" && fixture "$pf" && git init -q "$pf/docs" && git -C "$pf/docs" commit -q --allow-empty -m notes &&
    git -C "$pf" add -A 2>/dev/null || exit 1
expect -m 'unstage: .*docs ' refuse "private: first commit with the docs gitlink" pre_commit "$pf"

# Notes public: no ignored docs/, no docs repository
pp="$work/pp" && fixture "$pp" && git -C "$pp" commit -qm init && mkdir "$pp/docs" && echo x > "$pp/docs/x.md" &&
    echo a > "$pp/AGENTS.md" && git -C "$pp" add docs/x.md || exit 1
expect pass "public: docs/ file passes" pre_commit "$pp"
git -C "$pp" reset -q && git -C "$pp" add AGENTS.md && expect pass "public: AGENTS.md passes" pre_commit "$pp"

# Size: a warning past 200 lines added and removed outside tests
big='lines changed outside tests'
sz="$work/sz" && fixture "$sz" && seq 300 > "$sz/big.txt" && git -C "$sz" add big.txt && git -C "$sz" commit -qm init || exit 1
# lines <count> <file>: the file staged with that many lines, from HEAD's state
lines() { git -C "$sz" reset -q --hard && mkdir -p "$sz/$(dirname "$2")" && seq "$1" > "$sz/$2" && git -C "$sz" add "$2" || exit 1; }
lines 201 a.txt;                                        expect -m "$big" pass "size: warns past 200" pre_commit "$sz"
lines 200 a.txt;                                        expect -n "$big" pass "size: 200 doesn't warn" pre_commit "$sz"
lines 300 tests/a.txt;                                  expect -n "$big" pass "size: tests don't count" pre_commit "$sz"
git -C "$sz" reset -q --hard && head -c 4000 /dev/zero > "$sz/bin" && git -C "$sz" add bin || exit 1
expect -n "$big" pass "size: binary counts nothing" pre_commit "$sz"
git -C "$sz" reset -q --hard && git -C "$sz" mv big.txt moved.txt || exit 1
expect -n "$big" pass "size: a move counts nothing" pre_commit "$sz"
git -C "$sz" reset -q --hard && git -C "$sz" checkout -q -b other && echo other > "$sz/c.txt" && seq 300 > "$sz/d.txt" &&
    git -C "$sz" add c.txt d.txt && git -C "$sz" commit -qm other && git -C "$sz" checkout -q feat &&
    echo mine > "$sz/c.txt" && git -C "$sz" add c.txt && git -C "$sz" commit -qm mine || exit 1
! git -C "$sz" merge -q other >/dev/null 2>&1 && echo both > "$sz/c.txt" && git -C "$sz" add c.txt || exit 1
expect -n "$big" pass "size: merge skipped" pre_commit "$sz"

# The scrub list, through the core hooks
message 'chore: for Secretname\n';                      expect -m '^scrub: ' refuse "scrub: core commit-msg reads the message" commit_msg "$cm"
sc="$work/sc" && fixture "$sc" && echo 'for Secretname' > "$sc/b.txt" && git -C "$sc" add b.txt || exit 1
expect -m '^scrub: ' refuse "scrub: core pre-commit reads the staged lines" pre_commit "$sc"
git -C "$sc" rm -q --cached b.txt && echo x > "$sc/Secretname.txt" && git -C "$sc" add Secretname.txt || exit 1
expect -m '^scrub: ' refuse "scrub: core pre-commit reads file names" pre_commit "$sc"

# The paths HEAD's CODEOWNERS lists need a "Protected: <why>" line, checked in commit-msg
pr="$work/pr" && fixture "$pr" && mkdir -p "$pr/.github" "$pr/Sources/Models" "$pr/d" &&
    printf '# owners\n/a.txt @OWNER\n/Sources/Models/ @OWNER\n/Package.resolved\n/d/*\n!/d/x.txt\n' > "$pr/.github/CODEOWNERS" &&
    for f in a.txt Sources/Models/M.swift d/x.txt; do echo a > "$pr/$f"; done && git -C "$pr" add -A &&
    git -C "$pr" commit -qm init || exit 1
# change <repository> <file...>: each file staged with one more line, from HEAD's state
change() { r="$1" && shift && restore "$r" && for f; do mkdir -p "$r/$(dirname "$f")" && echo b >> "$r/$f"; done && git -C "$r" add -f "$@" || exit 1; }
change "$pr" a.txt
message 'fix: x\n';                                     expect -m 'a.txt' refuse "protected: no line" commit_msg "$pr"
message 'fix: x\n\nProtected: the owner asked for it\n'; expect pass  "protected: line passes" commit_msg "$pr"
message 'fix: x\n\nProtected:   \n';                    expect -m 'CODEOWNERS protects a.txt' refuse "protected: empty reason" commit_msg "$pr"
message 'fix: x\n\n# Protected: the owner asked\n';     expect -m 'CODEOWNERS protects a.txt' refuse "protected: comment doesn't count" commit_msg "$pr"
printf '/docs/\n' > "$pr/.gitignore"
message 'fix: x\n\nProtected: see docs/why.md\n';       expect -m 'docs/why.md' refuse "protected: reason names docs/" commit_msg "$pr"
rm "$pr/.gitignore"
message 'fix: x\n'
change "$pr" sub/Package.resolved;                      expect pass   "protected: anchored pattern" commit_msg "$pr"
change "$pr" PACKAGE.RESOLVED;                          expect pass   "protected: case matters" commit_msg "$pr"
change "$pr" Sources/Models/A/B.swift;                  expect -m 'Sources/Models/A/B.swift' refuse "protected: folder pattern with an owner" commit_msg "$pr"
printf 'b.txt\n' > "$pr/.gitignore" && change "$pr" b.txt; expect pass "protected: project's .gitignore ignored" commit_msg "$pr"
rm "$pr/.gitignore" && printf 'c.txt\n' > "$work/excludes" && git config --global core.excludesFile "$work/excludes" || exit 1
change "$pr" c.txt;                                     expect pass   "protected: global excludes ignored" commit_msg "$pr"
git config --global --unset core.excludesFile
mkdir -p "$work/tpl/hooks" && git config --global init.templateDir "$work/tpl" && change "$pr" a.txt || exit 1
expect -m 'CODEOWNERS protects a.txt' refuse "protected: a git template without info/" commit_msg "$pr"
git config --global --unset init.templateDir
# A git whose check-ignore dies, as a fatal error would make it.
mkdir -p "$work/badgit" && printf '#!/bin/sh\ncase " $* " in *" check-ignore "*) exit 128 ;; esac\nexec %s "$@"\n' "$(command -v git)" > "$work/badgit/git" &&
    chmod +x "$work/badgit/git" || exit 1
expect -m "couldn't match the changed paths" refuse "protected: a match that can't run refuses" env PATH="$work/badgit:$PATH" sh -c "cd '$pr' && GIT_EDITOR=vi ${SH:-sh} '$hook' '$work/msg'"
restore "$ph" && : > "$ph/.gitignore" && echo n > "$ph/docs/n.md" && git -C "$ph" add docs/n.md || exit 1
expect -m 'unstage: docs/n.md' refuse "private: a match that can't run counts as private" env PATH="$work/badgit:$PATH" sh -c "cd '$ph' && ${SH:-sh} '$pre'"
restore "$ph" && rm "$ph/docs/n.md"
change "$pr" d/x.txt;                                   expect -m 'd/x.txt' refuse "protected: ! lines dropped" commit_msg "$pr"
restore "$pr" && git -C "$pr" rm -q --cached a.txt || exit 1
expect -m 'a.txt' refuse "protected: delete" commit_msg "$pr"
restore "$pr" && git -C "$pr" mv Sources/Models/M.swift M.swift || exit 1
expect -m 'Sources/Models/M.swift' refuse "protected: rename out" commit_msg "$pr"
restore "$pr" && rm -f "$pr/M.swift"
# A merge brings the other side's protected changes, which CI checks on their own commits.
git -C "$pr" checkout -q -b other && echo b >> "$pr/a.txt" && git -C "$pr" commit -qam other && git -C "$pr" checkout -q feat &&
    git -C "$pr" merge -q --no-ff --no-commit other >/dev/null 2>&1 || exit 1
message 'fix: merge other\n';                           expect pass   "protected: merge skipped" commit_msg "$pr"
git -C "$pr" merge --abort || exit 1
# A real commit in a linked worktree, where git sets GIT_DIR for the hooks
git -C "$pr" worktree add -q -b wt "$work/prw" && git -C "$pr" config core.hooksPath "$root/core/hooks" || exit 1
expect -m 'a.txt' refuse "protected: in a linked worktree" sh -c "cd '$work/prw' && echo b >> a.txt && git commit -qam 'fix: x'"
expect pass "protected: a linked worktree leaves the main clone's core.bare" [ "$(git -C "$pr" config --bool core.bare)" = false ]

# Which CODEOWNERS: the first of .github/, the root and docs/, read from HEAD; docs/ skipped where the notes are private
# owners <name> <file:line...>: a repository whose HEAD has a.txt and each file with its one line
owners() {
    r="$work/$1" && shift && fixture "$r" && echo a > "$r/a.txt" || exit 1
    for o; do mkdir -p "$r/$(dirname "${o%%:*}")" && printf '%s\n' "${o#*:}" > "$r/${o%%:*}" || exit 1; done
    git -C "$r" add -Af && git -C "$r" commit -qm init || exit 1
}
owners pu CODEOWNERS:/a.txt && change "$work/pu" a.txt && : > "$work/pu/CODEOWNERS" && git -C "$work/pu" add CODEOWNERS || exit 1
expect -m 'a.txt' refuse "protected: unprotect and change at once" commit_msg "$work/pu"
owners pn && change "$work/pn" a.txt;                   expect pass   "protected: no CODEOWNERS" commit_msg "$work/pn"
owners pt CODEOWNERS:/a.txt && change "$work/pt" a.txt; expect -m 'a.txt' refuse "protected: root CODEOWNERS" commit_msg "$work/pt"
owners pb .github/CODEOWNERS:/b.txt CODEOWNERS:/a.txt && change "$work/pb" a.txt
expect pass "protected: .github wins" commit_msg "$work/pb"
owners pd .gitignore:/docs/ docs/CODEOWNERS:/a.txt && change "$work/pd" a.txt
expect pass "protected: private docs/CODEOWNERS ignored" commit_msg "$work/pd"

# core/claude/protected-edit.sh, Claude Code's PreToolUse hook: it asks before an edit of a path CODEOWNERS lists,
# matched with the main checkout's checks.sh against the checkout that holds the path.
cl="$work/cl" && fixture "$cl" && mkdir -p "$cl/.github" "$cl/scripts/hooks" && printf '/a.txt @OWNER\n/g/ @OWNER\n' > "$cl/.github/CODEOWNERS" &&
    echo a > "$cl/a.txt" && cp "$root/core/hooks/checks.sh" "$cl/scripts/hooks/" && git -C "$cl" add -A &&
    git -C "$cl" commit -qm init || exit 1
# claude_hook <json> [project]: the hook's stdout for one tool call, run as Claude runs it, from the project.
claude_hook() { (cd "${2:-$cl}" && printf '%s' "$1" | CLAUDE_PROJECT_DIR="${2:-$cl}" ${SH:-sh} "$root/core/claude/protected-edit.sh"); }
# asks <json> [project]: the hook exits 0 and answers ask. silent <json> [project]: it exits 0 and prints nothing.
asks() { out="$(claude_hook "$@")" && [ "$(printf '%s' "$out" | jq -r .hookSpecificOutput.permissionDecision)" = ask ]; }
silent() { out="$(claude_hook "$@")" && [ -z "$out" ]; }
edit() { printf '{"tool_name":"Edit","tool_input":{"file_path":"%s","old_string":"a","new_string":"b"}}' "$1"; }
expect pass "claude: protected edit asks" asks "$(edit "$cl/a.txt")"
expect pass "claude: other edit" silent "$(edit "$cl/b.txt")"
mkdir -p "$work/nogit" && export GIT_CEILING_DIRECTORIES="$work" || exit 1
expect pass "claude: outside any checkout" silent "$(edit "$work/nogit/a.txt")"
unset GIT_CEILING_DIRECTORIES
ln -s "$cl" "$work/cl-link" || exit 1
expect pass "claude: project through a link" asks "$(edit "$work/cl-link/a.txt")"
git -C "$cl" worktree add -q -b w1 "$cl/.claude/worktrees/w1" && git -C "$cl" worktree add -q -b w2 "$work/cl-w2" || exit 1
expect pass "claude: edit in a .claude/worktrees worktree asks" asks "$(edit "$cl/.claude/worktrees/w1/a.txt")"
expect pass "claude: edit in a sibling linked worktree asks" asks "$(edit "$work/cl-w2/a.txt")"
expect pass "claude: a new file in a new protected folder" asks "$(edit "$work/cl-w2/g/new/x.txt")"
git init -q "$cl/docs" && printf '/docs/\n' > "$cl/.gitignore" || exit 1
expect pass "claude: edit in the docs repository" silent "$(edit "$cl/docs/a.txt")"
rm -rf "$cl/docs" "$cl/.gitignore"
notebook() { printf '{"tool_name":"NotebookEdit","tool_input":{"notebook_path":"%s","new_source":"x"}}' "$1"; }
expect pass "claude: notebook_path" asks "$(notebook "$cl/a.txt")"
expect pass "claude: notebook_path of another file" silent "$(notebook "$cl/b.ipynb")"
expect pass "claude: no path asks" asks '{"tool_name":"Edit","tool_input":{}}'
expect pass "claude: empty path asks" asks "$(edit "")"
export JQ=/nonexistent/jq && expect pass "claude: no jq asks" asks "$(edit "$cl/b.txt")" && unset JQ
mkdir -p "$work/nochecks" || exit 1
expect pass "claude: no checks.sh asks" asks "$(edit "$cl/b.txt")" "$work/nochecks"
oldpath="$PATH" && export PATH="$work/badgit:$PATH" && expect pass "claude: a match that can't run asks" asks "$(edit "$cl/b.txt")"
export PATH="$oldpath"

# core/checks/ci-checks.sh, which runs the hooks on each commit of a pull request, with the base's hooks and CODEOWNERS.
# Commits are made without hooks, as a push with --no-verify would bring them.
ci="$root/core/checks/ci-checks.sh"
# ci_repo <name> [owners]: a repository whose first commit, the base, has the core hooks in scripts/hooks, a.txt,
# a .gitignore that makes the notes private and, unless owners is "none", a CODEOWNERS that lists /a.txt.
ci_repo() {
    r="$work/$1" && fixture "$r" && mkdir -p "$r/scripts/hooks" && echo a > "$r/a.txt" && printf '/docs/\n' > "$r/.gitignore" &&
        cp "$root/core/hooks/commit-msg" "$root/core/hooks/pre-commit" "$root/core/hooks/checks.sh" "$root/core/hooks/scrub.sh" \
            "$r/scripts/hooks/" || exit 1
    [ "${2:-}" = none ] || printf '/a.txt @OWNER\n' > "$r/CODEOWNERS" || exit 1
    git -C "$r" add -A && git -C "$r" commit -qm 'chore: base' && cibase="$(git -C "$r" rev-parse HEAD)" || exit 1
}
# put <file> <text>: the file written with that text and staged, in $r. cmt <message...>: a commit of what's staged.
put() { mkdir -p "$r/$(dirname "$1")" && printf '%s\n' "$2" > "$r/$1" && git -C "$r" add -f "$1" || exit 1; }
cmt() { git -C "$r" commit -q --allow-empty "$@" && short="$(git -C "$r" rev-parse --short HEAD)" || exit 1; }
# ci_run [repository]: ci-checks.sh over the base to HEAD, from the repository's root, as CI runs it.
ci_run() { (cd "${1:-$r}" && ${SH:-sh} "$ci" "$cibase" "$(git rev-parse HEAD)"); }

ci_repo ci-cg && put b.txt b && cmt -m 'feat: one' && put c.txt c && cmt -m 'fix: two'
expect pass "ci: good range" ci_run
# A type the first commit adds and uses, and the second drops: each commit is checked with its own CONTRIBUTING.md.
ci_repo ci-ct && sed 's/`perf`, /`perf`, `wip`, /' "$root/core/CONTRIBUTING.md" > "$r/CONTRIBUTING.md" && git -C "$r" add CONTRIBUTING.md &&
    cmt -m 'wip: add wip' && cp "$root/core/CONTRIBUTING.md" "$r/" && git -C "$r" add CONTRIBUTING.md && cmt -m 'chore: drop wip'
expect pass "ci: each commit's own CONTRIBUTING.md" ci_run
# Each bad commit below is undone by a later one, so reading the index or only the head misses it.
ci_repo ci-cm && put b.txt b && cmt -m 'feat: one' && put c.txt c && cmt -m 'bad message' && bad="$short" && put d.txt d && cmt -m 'fix: three'
expect -m "^$bad commit-msg: the subject" refuse "ci: bad middle message" ci_run
ci_repo ci-cp && put a.txt b && cmt -m 'fix: change a' && bad="$short" && put a.txt a && cmt -m 'fix: undo' -m 'Protected: undo'
expect -m "^$bad commit-msg: CODEOWNERS protects a.txt" refuse "ci: protected middle commit" ci_run
ci_repo ci-cv && put docs/x.md x && cmt -m 'docs: notes' && bad="$short" && git -C "$r" rm -q --cached docs/x.md && cmt -m 'chore: untrack'
expect -m "^$bad pre-commit: .*docs/x.md" refuse "ci: private path in a middle commit" ci_run
ci_repo ci-cl && put b.md 'see docs/plan.md' && cmt -m 'docs: link' && bad="$short" && git -C "$r" rm -q b.md && cmt -m 'chore: drop'
expect -m "^$bad see docs/plan.md" refuse "ci: docs/ link in a middle commit" ci_run
# An orphan branch: its root commit has no parent, so it's compared with the empty tree.
ci_repo ci-cr && git -C "$r" checkout -q --orphan other && put docs/x.md x && cmt -m 'chore: root'
expect -m "^$short pre-commit: .*docs/x.md" refuse "ci: root commit" ci_run
ci_repo ci-ci && put .gitignore '' && cmt -m 'chore: unignore' && put docs/x.md x && cmt -m 'docs: notes'
expect -m "^$short pre-commit: .*docs/x.md" refuse "ci: the base's .gitignore counts" ci_run
# The head's commit-msg passes everything and its checks.sh protects nothing; the base's are used.
ci_repo ci-cs && put scripts/hooks/commit-msg "$(printf '#!/bin/sh\n# CHECK_COMMIT\nexit 0')" && cmt -m 'chore: no check' &&
    printf 'protected_paths() { :; }\n' >> "$r/scripts/hooks/checks.sh" && git -C "$r" add scripts/hooks && cmt -m 'chore: none' &&
    put a.txt b && cmt -m 'fix: change a'
expect -m "^$short commit-msg: CODEOWNERS protects a.txt" refuse "ci: a commit can't switch off its check" ci_run
ci_repo ci-cu && put CODEOWNERS '' && cmt -m 'chore: unprotect a.txt' -m 'Protected: a.txt needs no owner' && put a.txt b && cmt -m 'fix: change a'
expect -m "^$short commit-msg: CODEOWNERS protects a.txt" refuse "ci: unprotected in the same pull request" ci_run
ci_repo ci-cn none && put CODEOWNERS '/a.txt @OWNER' && cmt -m 'chore: protect a.txt' && put a.txt b && cmt -m 'fix: change a'
expect pass "ci: base without CODEOWNERS" ci_run
# old_hooks: hooks from before CI, which don't know CHECK_COMMIT, put in $r's scripts/hooks and committed.
old_hooks() {
    for f in commit-msg pre-commit; do printf '#!/bin/sh\n. "$(dirname "$0")/checks.sh"\n' > "$r/scripts/hooks/$f" || exit 1; done
    printf 'refuse() { :; }\n' > "$r/scripts/hooks/checks.sh" && git -C "$r" add scripts/hooks && cmt -m 'chore: old hooks'
}
ci_repo ci-co && old_hooks && cibase="$(git -C "$r" rev-parse HEAD)" &&
    cp "$root/core/hooks/commit-msg" "$root/core/hooks/pre-commit" "$root/core/hooks/checks.sh" "$r/scripts/hooks/" &&
    git -C "$r" add scripts/hooks && cmt -m 'chore: new hooks' && put b.txt b && cmt -m 'feat: one'
expect -m "the head's" pass "ci: an older base hook" ci_run
put c.txt c && cmt -m 'bad message'
expect -m "^$short commit-msg: the subject" refuse "ci: an older base hook checks with the head's" ci_run
ci_repo ci-cq && old_hooks && cibase="$(git -C "$r" rev-parse HEAD)" && put b.txt b && cmt -m 'feat: one'
expect -m 'CHECK_COMMIT' refuse "ci: an old hook fails" ci_run
ci_repo ci-ch && git -C "$r" rm -rq scripts && cmt -m 'chore: no hooks' && cibase="$(git -C "$r" rev-parse HEAD)" && put b.txt b && cmt -m 'feat: one'
expect -m 'scripts/hooks' refuse "ci: no hooks fails" ci_run
ci_repo ci-cg2 && git -C "$r" checkout -q -b x && put b.txt b && cmt -m 'feat: one' && git -C "$r" checkout -q feat &&
    put c.txt c && cmt -m 'feat: two' && git -C "$r" merge -q --no-ff -m 'bad merge' x && put a.txt b && cmt -m 'fix: a' -m 'Protected: test' &&
    git -C "$r" checkout -q x && git -C "$r" merge -q --no-ff -m 'Merge feat into x' feat || exit 1
expect pass "ci: a merge's subject and changes aren't checked" ci_run
git -C "$r" checkout -q feat && git -C "$r" merge -q --no-ff -m 'Merge x' -m 'see docs/plan.md' x && short="$(git -C "$r" rev-parse --short HEAD)" || exit 1
expect -m "^$short see docs/plan.md" refuse "ci: a merge's message is checked" ci_run
ci_repo ci-fx && put b.txt b && cmt -m 'feat: add b' && put b.txt c && cmt -m 'fixup! feat: add b'
expect -m "^$short commit-msg: the subject" refuse "ci: a fixup! subject fails" ci_run
ci_repo ci-mp && put b.txt b && cmt -m 'Merge the two parsers'
expect -m "^$short commit-msg: the subject" refuse "ci: a Merge subject on a plain commit fails" ci_run
ci_repo ci-cz && rm "$r/.git/info/scrub-words" && put b.txt 'for Secretname' && cmt -m 'feat: one'
expect pass "ci: no scrub in CI" ci_run
ci_repo ci-cmn && git -C "$r" checkout -q -b main && put b.txt b && cmt -m 'feat: one'
expect pass "ci: no main check in CI" ci_run
# With -m, git keeps lines that start with #, so the stored message has one.
ci_repo ci-cc && cmt -m 'fix: x' -m '# see docs/plan.md'
expect -m "^$short # see docs/plan.md" refuse "ci: a # line naming docs/ in a stored message fails" ci_run

# scripts/hooks (the scrub check), in a throwaway repository with its own word list.
# The refusals must be scrub.sh's own, so a hook that can't find it fails them.
repo="$work/repo"
fixture "$repo" && cp -R "$root/scripts" "$repo/" && mkdir -p "$repo/core/hooks" &&
    cp "$root/core/hooks/scrub.sh" "$repo/core/hooks/" && printf 'Secretname\n\n' > "$repo/.git/info/scrub-words"
scrub_msg() { (cd "$repo" && ${SH:-sh} scripts/hooks/commit-msg "$work/msg"); }
scrub_staged() { (cd "$repo" && ${SH:-sh} scripts/hooks/pre-commit); }
message 'chore: x\n';                                   expect pass   "scrub: clean message" scrub_msg
message 'chore: x\n\n# secretname\n';                   expect -m '^scrub: ' refuse "scrub: word in a # line, other case" scrub_msg
message 'chore: x\n\nsee github.com/secretnameco\n';    expect pass   "scrub: listed word inside a longer word" scrub_msg
message "chore: x\n\nSecretname's notes\n";             expect -m '^scrub: ' refuse "scrub: listed word before an apostrophe" scrub_msg
message 'chore: x\n# ------------------------ >8 ------------------------\n+Secretname\n'
expect pass "scrub: word only below the scissors line" scrub_msg
(cd "$repo" && echo clean > a.txt && git add a.txt) && expect pass "scrub: clean staged file" scrub_staged
(cd "$repo" && echo 'for Secretname' > b.txt && git add b.txt) && expect -m '^scrub: ' refuse "scrub: word in a staged line" scrub_staged
(cd "$repo" && git rm -q --cached b.txt && echo x > Secretname.txt && git add Secretname.txt)
expect -m '^scrub: ' refuse "scrub: word in a file name" scrub_staged
(cd "$repo" && git rm -q --cached Secretname.txt) && printf '\n\n' > "$repo/.git/info/scrub-words"
expect -m '^scrub: ' refuse "scrub: list of blank lines" scrub_staged
rm "$repo/.git/info/scrub-words" && expect -m '^scrub: ' refuse "scrub: list missing" scrub_staged

[ "$failures" -eq 0 ] && echo "all passed" || { echo "$failures failed"; exit 1; }
