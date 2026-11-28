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
commit_msg() { (cd "$1" && ${SH:-sh} "${2:-$hook}" "$work/msg"); }

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

# The same hook with AI credit refused
sed 's/^ALLOW_AI_CREDIT=1$/ALLOW_AI_CREDIT=0/' "$hook" > "$work/commit-msg-refused" && chmod +x "$work/commit-msg-refused"
refused="$work/commit-msg-refused"
grep -q '^ALLOW_AI_CREDIT=0$' "$refused" || { echo "FAIL  could not switch AI credit off"; exit 1; }
message 'fix: x\n\nCo-Authored-By: Claude <a@b.c>\n';   expect refuse "refused: AI co-author" commit_msg "$cm" "$refused"
message 'fix: x\n\n# Generated with a tool\n';          expect refuse "refused: tool credit in a # line" commit_msg "$cm" "$refused"
message 'fix: x\n\nCo-Authored-By: Sam <a@b.c>\n';      expect pass   "refused: human co-author still passes" commit_msg "$cm" "$refused"

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
