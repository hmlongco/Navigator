---
name: swiftui-navigation-navigator
description: Guides SwiftUI navigation using the Navigator/NavigatorUI library—NavigationDestination enums, ManagedNavigationStack, NavigationLink(to:label), deep linking (send/onNavigationReceive), checkpoints, dismissible views, and modular/provided destinations. Use when implementing or discussing SwiftUI navigation with Navigator, deep linking, checkpoints, or NavigatorUI.
---

# SwiftUI Navigation with Navigator

When assisting the user with SwiftUI navigation in a project that uses Navigator or the NavigatorUI library, follow the conventions and patterns below. The skill is agent-agnostic; apply it whenever the user mentions Navigator, NavigatorUI, SwiftUI navigation, deep linking, checkpoints, managed navigation stack, or navigation destinations.

## When to use this skill

Apply this skill when the user:

- Mentions **Navigator**, **NavigatorUI**, or navigation in a Navigator-based codebase.
- Asks about **SwiftUI navigation** patterns (push, sheet, deep link, return to a screen).
- Works on **deep linking**, **checkpoints**, **routes**, or **dismissible** behavior.
- Defines or refactors **NavigationDestination** enums or **ManagedNavigationStack** usage.

## Core conventions

- **Destinations**: Enums conforming to `NavigationDestination` (Hashable + View). Provide a `body` that returns the correct view for each case; use associated values for parameters. Do not use `NavigationLink(value:label:)` or `NavigationLink(destination:label:)` for destination-driven navigation when using Navigator's no-registration flow.
- **Links**: Use **`NavigationLink(to: SomeDestination.case, label: { ... })`**. Navigator wraps the value internally; no per-type `navigationDestination(for: MyType.self)` registration is required.
- **Stack**: Use **`ManagedNavigationStack { ... }`** where a `NavigationStack` would go. It provides the `Navigator` in the environment and a single internal registration for all `NavigationDestination` types.
- **Navigator access**: Use **`@Environment(\.navigator) var navigator`**. Use the navigator for the *current* stack (from the closure of `ManagedNavigationStack` or from a child view). Do not assume the environment navigator is the root when inside a tab or presented view—it is the navigator for that stack.

## Quick patterns

- **Navigate / push**: `navigator.navigate(to: HomeDestinations.pageN(55))` or `navigator.push(HomeDestinations.pageN(55))`; override method with `navigator.navigate(to: destination, method: .sheet)` (or `.managedSheet`, `.cover`, `.managedCover`, `.send`).
- **Declarative**: `.navigate(to: $optionalDestination)` or `.navigate(trigger: $bool, destination: someDestination)`.
- **Checkpoint return**: Define with `NavigationCheckpoints` and `checkpoint()`; attach with `.navigationCheckpoint(KnownCheckpoints.home)`; return with `navigator.returnToCheckpoint(KnownCheckpoints.home)` or `.navigationReturnToCheckpoint(trigger: $flag, checkpoint: KnownCheckpoints.home)`.
- **Deep link / send**: `navigator.send(RootTabs.home, HomeDestinations.page2)` (or `navigator.perform(route: KnownRoutes.profilePhoto)`). Receive with `.onNavigationReceive { (tab: RootTabs) in ... return .auto }` or `.onNavigationReceive(assign: $selectedTab)`; for destinations use `.onNavigationReceive { (dest: HomeDestinations, navigator) in navigator.navigate(to: dest); return .auto }` or `.navigationAutoReceive(HomeDestinations.self)`.
- **Dismiss**: From inside a presented view use `navigator.dismiss()`. From a parent use `dismissPresentedViews()`, `dismissAnyChildren()`, or `dismissAny()` as appropriate. Custom sheets/covers presented outside `navigate(to:)` must be wrapped in **`ManagedPresentationView { content }`** or **`content.managedPresentationView()`** (or **`ManagedNavigationStack { content }`** if the sheet has its own stack) so Navigator can manage and dismiss them.
- **Lock**: Use **`.navigationLocked()`** on a view to make global `dismissAny()` throw (e.g. during a transaction).

## Topic index (reference docs)

For detailed explanations, code samples, and "why" notes, use the reference files:

- **[Destinations](reference/Destinations.md)** — Defining NavigationDestination enums, body, associated values, delegation to a private View for environment/DI, destination-as-view in sheets, coordination pattern, external provided views.
- **[Navigation](reference/Navigation.md)** — ManagedNavigationStack, why no registration is needed (AnyNavigationDestination), NavigationLink(to:label), imperative and declarative navigation, NavigationMethod, modular cards/tabs.
- **[Dismissible](reference/Dismissible.md)** — Navigation tree, dismiss vs dismissPresentedViews vs dismissAnyChildren vs dismissAny, navigationLocked, state-driven modifiers, wrapping custom sheets/covers.
- **[Checkpoints](reference/Checkpoints.md)** — Defining and establishing checkpoints, returning and returning with value, state-driven return, state restoration, coordinator pattern.
- **[Deep linking](reference/DeepLinking.md)** — send(values:), onNavigationReceive and resume types, routes vs destinations, NavigationRouteHandling, perform(route:), one router for URL and in-app.
- **[Provided destinations](reference/ProvidedDestinations.md)** — NavigationProvidedDestination, onNavigationProvidedView, NavigationProvidedView and placeholders, modular apps.

## Do / don't

- **Do**: Use `NavigationLink(to: Destination.case)`; use `ManagedNavigationStack`; use checkpoints for "return to this place"; use send/receive for deep linking and tab switching; wrap custom presented views in `ManagedPresentationView` or `.managedPresentationView()` when Navigator should manage them.
- **Don't**: Use `NavigationLink(destination:label:)`; use `NavigationLink(value:label:)` for destination types when aiming for no-registration flow (unless you explicitly register); present sheets or covers without wrapping when Navigator needs to dismiss or deep-link into the app.

## Root setup

Create a root `Navigator(configuration: NavigationConfiguration(...))` and apply **`.navigationRoot(navigator)`** at the root view. Register provided destinations and receive handlers (e.g. `.onNavigationProvidedView(...)`, `.onNavigationRoute(router)`, `.onNavigationReceive(...)`) above `.navigationRoot(navigator)` as needed.

## References

- In-repo: README, Documentation.docc, NavigatorDemo app for patterns.
- External: [Navigator Documentation](https://hmlongco.github.io/Navigator/documentation/navigatorui/); Medium articles — Advanced Navigation Destinations, Eliminating Navigation Registrations, Advanced Deep Linking, Navigation Checkpoints, SwiftUI Navigation With Dismissible.
