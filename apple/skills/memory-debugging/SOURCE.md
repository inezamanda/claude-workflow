# Source

- Repository: https://github.com/CharlesWiltgen/Axiom
- Commit: ffafd3b3e0dbaaa60b753ca4a835ae6603b873e1 (plugin version 27.8.1, 8 Nov 2026)
- File: `.claude-plugin/plugins/axiom/skills/axiom-performance/skills/memory-debugging.md`
- License: MIT, © 2025 Charles Wiltgen; `LICENSE` beside this file is Axiom's, unchanged.
- Changed: frontmatter added (the first four lines of `SKILL.md`: `name` and `description`, written here). Axiom's text follows unchanged; `tail -n +5 SKILL.md | shasum -a 256` gives `131471392a390b1e7e17ade71d8c327c18fc038aecf81997ab65aca26625f555`, the original's.
- Read in full on 28 Nov 2026 before it was copied.

Line numbers below are `SKILL.md`'s.

## Links to skills copied here

`skills/performance-profiling.md` (line 501) is the `performance-profiling` skill.

## Links that point nowhere

These name Axiom files or skills that weren't copied.

- `axiom-swiftui (skills/layout-ref.md)`: lines 129, 174. The one that matters: it holds the measurements and the fix for lazy containers' memory, which lines 125-129 and 171-174 only point to. `swiftui-performance` points there too.
- `axiom-performance (skills/metrickit-ref.md)`: line 167; `skills/metrickit-ref.md`: line 501
- `axiom-integration` (`skills/timer-patterns.md`): line 202
- `skills/objc-block-retain-cycles.md`, `axiom-build (skills/lldb.md)`, `axiom-tools (skills/xcsym-ref.md)`: line 501
- `xcsym crash --from-metrickit` (line 357) is a tool that comes with Axiom, not with Xcode.

## Problems in the text

Kept as they are, since the text is a copy.

- Lines 66, 344 and 355 add `deinit { print(…) }` to find what isn't freed. That's fine while debugging, but this project's `no_print` SwiftLint rule refuses a commit that keeps it in app code; `CODING.md` logs with `os.Logger`.
- The leak shares ("50% of leaks" for timers, line 180; the split on line 340) have no source.
- The Swift 6.4 `[#ImplicitStrongCapture]` warning (lines 290-328) wasn't checked against the compiler when this was copied.
