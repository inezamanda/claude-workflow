#!/bin/sh
# Reads text on stdin and fails if it contains a word or phrase from .git/info/scrub-words.
# The list lives inside .git, so the words it keeps out of the repository are never committed themselves.
# Usage: <text> | scripts/scrub.sh "<what is being checked>"

list="$(git rev-parse --git-path info/scrub-words)"
patterns="$(mktemp)" || exit 1
trap 'rm -f "$patterns"' EXIT

# A blank line would match everything, so drop blank lines before using the list.
[ -f "$list" ] && grep -v '^[[:space:]]*$' "$list" > "$patterns"
if [ ! -s "$patterns" ]; then
    echo "scrub: $list is missing or empty. Add one word or phrase per line." >&2
    exit 1
fi

# Whole words only, so a listed name still matches on its own but not inside a longer word, such as a username.
hits="$(grep -inwFf "$patterns")"
if [ -n "$hits" ]; then
    echo "scrub: $1 contains a word from $list:" >&2
    echo "$hits" >&2
    exit 1
fi
