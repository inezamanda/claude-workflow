# How we write code

<!-- A starting point for an app on Apple platforms (Swift, SwiftUI). Copy it to the project's root, then adapt: name the real folders, entry points and checks, and delete what doesn't apply. CONTRIBUTING.md covers the process around it. -->

This is the guide for writing code here: where things go, how they're named, how they're built and how they're tested. Most rules come from something that went wrong or was fixed; when one is added, say what it came from.

## 1. Where code goes

Keep logic that doesn't need UIKit, SwiftUI or the system's services in a Swift package with no UI imports, so its tests run on a Mac without a simulator. It reaches the platform through small protocols that the app implements.

The app is organised by feature, around a few shared layers:

| Folder | Holds |
| --- | --- |
| `App/` | The entry point, the setup that creates the app's long-lived objects, and the root view that puts the features together. |
| `Features/<Feature>/` | One folder per feature: something the user can name, with its views and models side by side. |
| `<Domain>/` | How the app's own kind of data reads and is shown, shared by features. <!-- Name it for the domain. --> |
| `Platform/` | The app's side of iOS: storage, the Keychain, permissions, logging, system links. |
| `DesignSystem/` | Views, styles and helpers that know nothing of the domain. |
| `Resources/` | The asset catalog, the app icon, the string catalog and the privacy manifest. |
| `Debug/` | DEBUG-only tools. |

Rules that keep the folders honest:

1. **A feature is something the user can name.** Its own screens and state live in its folder.
2. **A feature uses only the shared layers and other features' entry points**, never their internals. Anything else two features need goes to a shared layer.
3. **`DesignSystem/` knows no domain types, from its first use.** A view that knows the domain stays in its feature; when two features need it, its look moves to `DesignSystem/` or the view moves to `<Domain>/`.
4. **There's no folder for extensions.** An extension sits beside its user; one that several features use goes to `DesignSystem/` (UI) or `Platform/` (system).
5. **`Platform/` knows nothing about features.** It reports state and errors; which screen shows is a feature's decision.
6. **The layers go one way:** `<Domain>/` may use `Platform/` and `DesignSystem/`, those two use none of the others, and `App/` may use all of them.

A folder grows subfolders by part of the feature, never by layer (`Models/`, `Views/`): when it passes about eight files and a part of it has at least three. A part's main model and view stay at its root. The change that takes a folder past the threshold splits it first, in a move-only commit.

Tests follow the code: the app's unit tests mirror its folders, with shared stand-ins in `Support/`; UI tests have a class per screen on a shared base class, which is where helpers shared between screens go.

### Architecture

- **One `@MainActor @Observable` model per screen or flow, and a thin view.** The model holds state and logic; the view shows state and passes on taps.
- **Decisions are pure functions**, tested without UI.
- **Dependencies come in through `init`, as small protocols**, so tests can use stand-ins. Add a protocol when a test needs one, not before. No singletons of our own.
- **App-wide services go through `Platform/`.** A framework only one feature needs stays in that feature, behind a protocol when tests need a stand-in.
- **Name suffixes replace layer folders:** `…Model`, `…View`, `…Row`, `…Card`.
- **DEBUG-only code stays inside `#if DEBUG`**, in `Debug/` where possible, so it can never reach a release build.

## 2. Files and names

- **One main type per file, named after it.** Types that belong to it stay with it: the protocol it depends on, a value it returns or holds. A type that is its own idea, or that several main types share, gets its own file.
- **A screen is `XModel` + `XView`.** Objects every screen shares are named for their job; rows and parts of a screen for what they show.
- **Extensions go in `Type+Purpose.swift`**, beside their user.
- **Follow Apple's [API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)** and use SwiftUI's own words: `systemImage` for an SF Symbol name, `onDelete` for a callback.
- **American spelling in identifiers**, as in Apple's APIs.
- **Test files are named after what they test.**

## 3. Swift

- **Swift 6 with complete strict concurrency.** If you think you need `@unchecked Sendable` or `nonisolated(unsafe)`, explain why in the pull request.
- **The app's default isolation is the main actor.** A pure helper that a nonisolated type calls needs `nonisolated`; the compiler tells you where.
- **Calls that can block run off the caller's actor**, like the Keychain or file I/O.
- **Errors are handled, not swallowed.** Map them to what the user sees and log only their domain and code. `(try? load()) ?? []` turns a failure into an empty list, which tells the user their data is gone. `try?` is fine only where failing really changes nothing, like removing a temporary file.

## 4. SwiftUI

**Views stay thin.** A setting that has to be saved and applied is one call on the model, not two steps in a view. A stored setting is applied wherever its owner is created, not only where it changes.

**A view never keeps its own copy of state that lives elsewhere.** `@State` is for what only the view knows, like a text field's draft. A copy of a model's value in `@State` is taken once and goes stale.

**Small views get only the data they show**, not the whole screen model. Callbacks are named for the event: `onHide`, `onDelete`, `onDismiss`.

**Pick the right tool to reuse or customise:**

| You want to | Use |
| --- | --- |
| Restyle a system control | A style type (`ButtonStyle`, `LabelStyle`) |
| Reuse a decoration | A `ViewModifier` with a `View` extension |
| Build new content | A `View` |
| Format a value | A `FormatStyle` |
| Add a convenience to a system type | An extension |

A style built on a system style keeps what the system gives for free: pressed and disabled looks, Dynamic Type, the platform's materials.

**Prefer what the platform already has:** standard toolbar buttons, `Form`, `List`, swipe actions, the system's formatters. Build our own only when the design needs something the system doesn't do.

**Details that keep coming back:**

- Colours come from the asset catalog's generated symbols, `Color(.warning)`, never `Color("Warning")`: a typo then fails to compile. Every colour has a Dark Mode variant, and text keeps a contrast of at least 4.5:1. A background colour is never used for text.
- Every text the user sees is in the string catalog under a short key. What the user typed, and numbers, use `Text(verbatim:)`.
- Layouts work at accessibility text sizes.
- Decorative images are hidden from VoiceOver; the text next to them says what they mean.
- Elements that UI tests use get an `accessibilityIdentifier`.
- Move focus only after an alert or sheet has fully closed, never with a fixed delay.
- Work tied to a view's lifetime uses `.task`, which SwiftUI cancels when the view goes away.

## 5. Reuse

Before building a view, a style or a helper, check `DesignSystem/` and the feature you're in. Extract a shared piece when it's used a second time, not before: a shared piece with one user is harder to follow than the code it replaced.

## 6. Values and formats

- **Identifiers of stored data never change once a build has shipped**: Keychain services, file and folder names, settings keys, the raw values an enum stores. Changing one orphans what's already stored. Define each once, and pin it with a test.
- **Build settings are read from Info.plist**, so they always match the entitlements: App Groups and Keychain access groups. Debug builds use their own bundle id and groups, so a development build never reaches the shipped app's data.
- **Calendar days are calendar days.** A date without a time is read in a fixed calendar and time zone, so no time zone moves it.
- **Once a stored format ships, it stays.** A change needs a migration and a test that opens data in the old format.

## 7. Privacy and security

- Log through `os.Logger`, with `.private` on anything that might hold the user's data.
- Secrets live in the Keychain only, never in `UserDefaults`, a file or a log.
- Nothing on screen pretends to work. A row for a feature that doesn't exist yet stays out until it does.
- No new dependency without asking first; every dependency can read what the app reads.

## 8. Tests

- **Test first, and watch it fail.** Write a stub that compiles, run the test against it, then implement.
- **For logic that guards data, break the code on purpose** and check a test fails. Then put it back.
- **Tests never wait forever.** Anything that waits has a timeout. Use `try #require` before indexing into a result.
- **The simulator isn't a phone.** Anything that touches system folders, file protection, the Keychain or Face ID also runs on a device before it's merged.
- **A refactor proves it changed nothing**: compare the code before and after, run every test, and compare the UI test screenshots.

## 9. Style and comments

swift-format handles layout and SwiftLint handles naming, size and the rules above that a tool can check. Before you commit:

```sh
swift format lint --strict -r <folders>
swiftlint lint --strict
```

Every Swift file starts with the header Xcode creates.

Add a comment when the code can't say it for itself: why something is done this way, a rule that has to keep holding, or a side effect nobody would guess. Keep it to a line or two. If a comment only repeats the code, leave it out.

## 10. Before you commit

1. Is this the simplest thing that works? What would you remove?
2. Is there already a component, extension or helper for it?
3. Do the names read like Apple's and SwiftUI's?
4. Can the logic be tested without UI, and is it?
5. Did the new test fail first?
6. What about empty, error, Dark Mode, large text and VoiceOver?
7. Have you used the screen by hand? Every keyboard, sheet, picker and alert can be closed, nothing overlaps when the keyboard is up, and everything that can be tapped looks tappable.
8. Does it behave the same on a device as in the simulator?
9. Does it match the design, and does nothing on screen claim to work before it does?
