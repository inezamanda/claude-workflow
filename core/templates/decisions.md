# Decisions log

Choices made for <project>, newest at the bottom of the table. The design doc says what the project does; this log says what was chosen where the design doc leaves it open, and why.

The log is append-only: a changed decision gets a new row that names the row it replaces, and old rows are never edited. That way two branches that add rows merge cleanly, with `merge=union` in `.gitattributes`. Search it rather than reading it whole, by area or by word: `grep -n -E '^\| [0-9-]+ \| [^|]*<Area>' docs/decisions.md`. Past about 300 lines, replaced rows and rows for finished work move to `decisions-archive-<year>.md`, in a commit of their own.

<!-- Keep the areas to a short list, such as Data, UI, Sync, Tools, so a search by area finds them all. If the log lives somewhere other than docs/decisions.md, change its path in .gitattributes and in the search above. -->

| Date | Area | Decision | Why | Who |
| --- | --- | --- | --- | --- |
| <YYYY-MM-DD> | <area> | <decision> | <why> | <maintainer or agent> |

## Open questions

| Raised | Question | Where things stand |
| --- | --- | --- |
| <YYYY-MM-DD> | <question> | <where things stand> |
