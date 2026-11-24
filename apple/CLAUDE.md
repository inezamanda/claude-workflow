# Apple platform projects (Swift, SwiftUI, UIKit)

These add to `~/.claude/CLAUDE.md`. A project's own CLAUDE.md, linter and formatter win where they differ.

## Code smells (Swift / iOS)

In code you're already changing, fix a smell when the fix is small and stays inside the task. If it needs a new file, type or protocol, or a rename across files, propose it first. Elsewhere, report it; don't refactor unasked. Moves, renames and deletions go in their own commit, apart from changes in behaviour.

Where a project runs SwiftLint or swift-format, their limits are the limits. The numbers below are for projects without them.

| Smell | Signal | Action |
|---|---|---|
| Long function | 50+ lines, or does more than one thing | Split into named functions |
| Deep nesting | 3+ levels of `if`, `for` or closures | `guard` or an early return |
| Massive view or view controller | Logic, networking or storage inside a `View` or `UIViewController` | Move it to a model (in SwiftUI, an `@Observable` one) and keep the view thin |
| Duplicated logic | The same logic in 2+ places | Extract a shared function |
| Long parameter list | More than 5 parameters | Group related values in a struct |
| Magic values | Unnamed numbers; raw strings for keys, identifiers, colours or text the user sees | A named constant or `enum`; colours and text from the asset and string catalogs |
| Stringly typed | Strings standing in for a state or a kind | An `enum` |
| Force operations | `!`, `try!`, `as!` | `guard let`, `throws`, `as?`; in tests, `try #require` or `XCTUnwrap` |
| Swallowed errors | An empty `catch {}`; a `try?` that hides a failure the user would care about | Handle it, rethrow it, or log it with context and no personal data. `try?` is fine where failing changes nothing |
| Retain cycle | A stored closure that captures `self` strongly | Pass values in, or `[weak self]`; never `unowned` |
| Blocking the main thread | File I/O, the Keychain or heavy work on the main actor | Run it off the main actor (`@concurrent` or an actor in Swift 6, a background queue in older code) |
| Hidden global state | Singletons of our own, a mutable `static var` | Pass dependencies in through `init` |
| Copied state | `@State` holding a copy of a model's value | Read it from the model |
| Boolean flag argument | A `Bool` parameter that switches a function between two behaviours | Two functions, or an `enum` |
| Dead code | Unused functions, imports, commented-out code | Delete it |
| Misleading name | The name no longer matches what it does | Rename the Swift identifier. Never change a stored value (a UserDefaults or Keychain key, a file name, an enum's stored raw value) without a migration |

Report format: severity (bug risk, maintainability, style), then one line per finding.
