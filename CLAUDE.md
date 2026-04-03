# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
swift build
swift test
swift test --filter NavigatorUITests/NavigatorCoreTests/testNavigatorInitialization
./docs.sh   # generate DocC documentation → docs/
```

## Architecture

Navigator is a SwiftUI navigation framework built on `NavigationStack`. It eliminates manual `navigationDestination` registrations and supports deep linking, checkpoints, and modular app patterns.

**Platforms:** iOS 17+, macOS 14+, tvOS 17+, watchOS 10+, visionOS 1+
**Swift:** 6.2, strict concurrency, `@MainActor` isolation throughout

### Core pattern

Navigation is driven by enums conforming to `NavigationDestination` (Hashable + View). Each enum case is a screen; associated values pass parameters. The enum's `body` returns the view for each case — no per-destination registration needed.

**`ManagedNavigationStack`** replaces `NavigationStack`. It creates a `Navigator`, injects it into the SwiftUI environment, and registers a single `AnyNavigationDestination` handler so any destination type can be pushed without extra setup. Access the navigator with `@Environment(\.navigator) var navigator`.

**`Navigator`** (`@Observable`, `@MainActor`) manages the navigation path, sheet/cover presentations, checkpoints, locks, and the parent–child hierarchy that mirrors the presentation tree.

### Key patterns

- **NavigationMethod** — how a destination is presented: `.push`, `.sheet`, `.managedSheet`, `.cover`, `.managedCover`, `.send`
- **Checkpoints** — named return points; any view can return to a named place without knowing the stack structure; support typed value returns
- **Deep linking via send/receive** — `navigator.send(values:)` broadcasts `Hashable` values; views subscribe with `.onNavigationReceive`; routes abstract multi-step sequences behind a single `perform(route:)` call
- **Modular destinations** — `NavigationProvidedDestination` lets a module declare destinations without knowing the view implementations; the app root registers providers via `.onNavigationProvidedView`
- **Dismissible tree** — `ManagedPresentationView` / `.managedPresentationView()` registers custom sheets with Navigator so `dismissAny()` and checkpoints can traverse the full presentation tree

### Source layout

```
Sources/NavigatorUI/NavigatorUI/
├── Core/      # Navigator, protocols, NavigationMethod, send/receive, checkpoints, locking
├── Views/     # ManagedNavigationStack, ManagedPresentationView, NavigationProvidedView
└── Extensions/# NavigationLink(to:label:), LazyState
```

Tests use Apple's Testing framework (not XCTest). `Tests/NavigatorUITests/Helpers/MockDestination.swift` is the primary fixture.

## Skill

A Claude skill with detailed pattern references is at `.claude/skills/swiftui-navigation-navigator/`. Import `SKILL.md` and the `reference/` subfolder into your project's `.claude/skills/` directory to get inline guidance on destinations, navigation, checkpoints, deep linking, dismissible views, and provided destinations.
