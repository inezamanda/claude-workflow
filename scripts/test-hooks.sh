#!/bin/sh
# Runs the hooks against messages and staged changes that must pass or be refused.
# Usage: scripts/test-hooks.sh (from anywhere in the repository)

root="$(git rev-parse --show-toplevel)" || exit 1
mkdir -p "$root/build" && work="$(mktemp -d "$root/build/test-hooks.XXXXXX")" || exit 1
trap 'rm -rf "$work"' EXIT
failures=0

# expect pass|refuse <name> <command...>
expect() {
    want="$1" name="$2"
    shift 2
    if "$@" >/dev/null 2>&1; then got=pass; else got=refuse; fi
    if [ "$got" = "$want" ]; then echo "ok    $name"; else echo "FAIL  $name (wanted $want, got $got)"; failures=$((failures + 1)); fi
}

message() { printf "$1" > "$work/msg"; }

# core/hooks/commit-msg
hook="$root/core/hooks/commit-msg"
message 'feat(sync): keep the draft\n';                 expect pass   "conventional subject" "$hook" "$work/msg"
message 'fix!: drop the old format\n';                  expect pass   "breaking change without a scope" "$hook" "$work/msg"
message 'fixup! feat(sync): keep the draft\n';          expect pass   "fixup subject" "$hook" "$work/msg"
message 'Merge pull request #1 from a/b\n';             expect pass   "merge subject" "$hook" "$work/msg"
message 'Keep the draft\n';                             expect refuse "no type" "$hook" "$work/msg"
message 'feature: keep the draft\n';                    expect refuse "unknown type" "$hook" "$work/msg"
message 'fix: keep the draft.\n';                       expect refuse "full stop" "$hook" "$work/msg"
message "fix: $(printf '%0101d' 0 | tr 0 a)\n";         expect refuse "subject over 100 characters" "$hook" "$work/msg"
message "fix: $(printf '%080d' 0 | tr 0 a)\n";          expect pass   "subject over 72 only warns" "$hook" "$work/msg"
message 'fix: x\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>\n'; expect pass "AI co-author, allowed by default" "$hook" "$work/msg"
message 'fix: x\n\nCo-Authored-By: Sam <a@b.c>\n';      expect pass   "human co-author" "$hook" "$work/msg"
message '\n# only comments\n';                          expect refuse "empty message" "$hook" "$work/msg"

# The same hook with AI credit refused
sed 's/^ALLOW_AI_CREDIT=1$/ALLOW_AI_CREDIT=0/' "$hook" > "$work/commit-msg-refused" && chmod +x "$work/commit-msg-refused"
refused="$work/commit-msg-refused"
grep -q '^ALLOW_AI_CREDIT=0$' "$refused" || { echo "FAIL  could not switch AI credit off"; exit 1; }
message 'fix: x\n\nCo-Authored-By: Claude <a@b.c>\n';   expect refuse "refused: AI co-author" "$refused" "$work/msg"
message 'fix: x\n\n# Generated with a tool\n';          expect refuse "refused: tool credit in a # line" "$refused" "$work/msg"
message 'fix: x\n\nCo-Authored-By: Sam <a@b.c>\n';      expect pass   "refused: human co-author still passes" "$refused" "$work/msg"

# scripts/hooks (the scrub check), in a throwaway repository with its own word list
repo="$work/repo"
git init -q "$repo" && cp -R "$root/scripts" "$repo/" && printf 'Secretname\n\n' > "$repo/.git/info/scrub-words"
scrub_msg() { (cd "$repo" && scripts/hooks/commit-msg "$work/msg"); }
message 'chore: x\n';                                   expect pass   "scrub: clean message" scrub_msg
message 'chore: x\n\n# secretname\n';                   expect refuse "scrub: word in a # line, other case" scrub_msg
message 'chore: x\n\nsee github.com/secretnameco\n';    expect pass   "scrub: listed word inside a longer word" scrub_msg
message "chore: x\n\nSecretname's notes\n";             expect refuse "scrub: listed word before an apostrophe" scrub_msg
message 'chore: x\n# ------------------------ >8 ------------------------\n+Secretname\n'
expect pass "scrub: word only below the scissors line" scrub_msg
(cd "$repo" && echo clean > a.txt && git add a.txt) && expect pass "scrub: clean staged file" sh -c "cd '$repo' && scripts/hooks/pre-commit"
(cd "$repo" && echo 'for Secretname' > b.txt && git add b.txt) && expect refuse "scrub: word in a staged line" sh -c "cd '$repo' && scripts/hooks/pre-commit"
(cd "$repo" && git rm -q --cached b.txt && echo x > Secretname.txt && git add Secretname.txt)
expect refuse "scrub: word in a file name" sh -c "cd '$repo' && scripts/hooks/pre-commit"
(cd "$repo" && git rm -q --cached Secretname.txt) && printf '\n\n' > "$repo/.git/info/scrub-words"
expect refuse "scrub: list of blank lines" sh -c "cd '$repo' && scripts/hooks/pre-commit"
rm "$repo/.git/info/scrub-words" && expect refuse "scrub: list missing" sh -c "cd '$repo' && scripts/hooks/pre-commit"

[ "$failures" -eq 0 ] && echo "all passed" || { echo "$failures failed"; exit 1; }
