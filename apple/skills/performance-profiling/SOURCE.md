# Source

- Repository: https://github.com/CharlesWiltgen/Axiom
- Commit: ffafd3b3e0dbaaa60b753ca4a835ae6603b873e1 (plugin version 27.8.1, 8 Nov 2026)
- File: `.claude-plugin/plugins/axiom/skills/axiom-performance/skills/performance-profiling.md`
- License: MIT, © 2025 Charles Wiltgen; `LICENSE` beside this file is Axiom's, unchanged.
- Changed: frontmatter added (the first four lines of `SKILL.md`: `name` and `description`, written here). Axiom's text follows unchanged; `tail -n +5 SKILL.md | shasum -a 256` gives `1096a15016baaba1e4254cb7411b6f83a297ffc86798bcfea52ede9dc4d5c2f1`, the original's.
- Read in full on 28 Nov 2026 before it was copied.

Line numbers below are `SKILL.md`'s.

## Links to skills copied here

`axiom-performance (skills/memory-debugging.md)` (lines 15, 27, 201, 783, 1104) is the `memory-debugging` skill; `axiom-swiftui` as the "performance reference" (lines 15, 31, 1104) is `swiftui-performance`.

## Links that point nowhere

These name Axiom files or skills that weren't copied. Each is a pointer to further reading; the text around it stands without it.

- `axiom-performance (skills/trace-comparison.md)`: lines 562, 1104 (`xcprof compare` for CI)
- `axiom-performance (skills/xctrace-ref.md)`: line 795
- `axiom-performance (skills/metrickit-ref.md)`: lines 1089, 1104; and `metrickit-ref` on line 580
- `axiom-concurrency`: lines 570, 1104
- `axiom-ai (skills/foundation-models-ref.md)`: lines 574, 1104
- "ui-testing": line 527

## Problems in the text

Kept as they are, since the text is a copy.

- The "lines …" references in Real-World Examples (lines 861, 890, 918, 955, 975, 980) point at the wrong sections, even in Axiom's own file. Look the sections up by name.
- Line 189: "50ms on main thread per frame = smooth UI (60fps)". A 60 Hz frame is 16.7 ms, so 50 ms drops about three frames.
- Line 470: "Add `@Index` in schema" for an `@NSManaged` property. That's SwiftData's; in Core Data, an index is set on the entity in the model editor.
- Lines 929-941 fix a slow load with `DispatchQueue.global().async`. This project's `CODING.md` uses Swift concurrency; line 566 of this same file moves work off the main actor with `Task { @concurrent in … }`.
- Line 292: "Instagram uses 400-600MB on load" has no source.
