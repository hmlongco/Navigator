# Navigation (reference)

Navigator uses **ManagedNavigationStack** and a single internal registration so you can push any **NavigationDestination** type without registering each type with `navigationDestination(for: MyType.self)`.

## ManagedNavigationStack

Use **`ManagedNavigationStack { ... }`** wherever you would use a `NavigationStack`. It:

- Creates a `NavigationStack` and binds it to a `Navigator`.
- Injects the **Navigator** into the environment for that stack.
- Registers **one** type internally—`AnyNavigationDestination`—so all destination types can be pushed without per-type registration.

Access the navigator from the content closure or from any child view via **`@Environment(\.navigator) var navigator`**. That navigator is the one managing *that* stack (e.g. the current tab's stack), not necessarily the root.

## Why no registration is needed

SwiftUI's `NavigationLink(value:label:)` requires the value's type to be registered with `navigationDestination(for: Type.self)`. Navigator avoids that by:

1. Registering **only** `AnyNavigationDestination` in every ManagedNavigationStack.
2. Providing **`NavigationLink(to: label:)`**, which wraps your destination in `AnyNavigationDestination` and uses `NavigationLink(value: label:)` with that wrapper. So SwiftUI only ever sees one type.

Therefore: use **`NavigationLink(to: HomeDestinations.page3) { ... }`**, not `NavigationLink(value: HomeDestinations.page3) { ... }`, when you want zero per-type registration. Feature modules can then push their own destination types (e.g. from cards or tabs) without the root view registering every type.

## Imperative navigation

- **`navigator.navigate(to: destination)`** — Navigate using the destination's **NavigationMethod** (push, sheet, cover, etc.).
- **`navigator.push(destination)`** — Push onto the current stack (ignores method).
- **`navigator.navigate(to: destination, method: .sheet)`** — Override method (e.g. `.sheet`, `.managedSheet`, `.cover`, `.managedCover`, `.send`).

Use the navigator from the **current** stack's environment (the one for the ManagedNavigationStack that contains the view).

## Declarative navigation

- **`.navigate(to: $optionalDestination)`** — When the binding becomes non-nil, navigate to that destination then clear it. Use for state-driven navigation.
- **`.navigate(trigger: $bool, destination: someDestination)`** — When the binding becomes true, navigate to the destination then set the trigger back to false.

## NavigationMethod

Each destination can declare how it should be presented by default via a **`method`** property (or extension): **`.push`**, **`.sheet`**, **`.managedSheet`**, **`.cover`**, **`.managedCover`**, **`.send`**. `navigate(to:)` uses that unless you pass an explicit `method`. `.managedSheet` and `.managedCover` wrap the destination in a ManagedNavigationStack so the sheet has its own navigator and stack.

**Note**: Destinations presented via **NavigationLink(to:label)** are always **pushed**; SwiftUI does not support presenting a sheet from a link. Use imperative `navigate(to:)` or declarative `.navigate(to:)` / `.navigate(trigger:destination:)` for sheet/cover.

## Values, not destination views

Use **values** (destination enum cases) with Navigator, not `NavigationLink(destination: SomeView())`. Mixing `NavigationLink(destination:label:)` with Navigator can break programmatic navigation and stack behavior. Prefer `NavigationLink(to: Destination.case)` and destination-driven presentation.
