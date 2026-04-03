# Destinations (reference)

Navigation in Navigator is driven by **enumerated destination values** that conform to the `NavigationDestination` protocol. The protocol requires `Hashable`, `Equatable`, `Identifiable`, and `View`; the enum's `body` provides the view for each case.

## Protocol and enum body

- **NavigationDestination** conforms to View, so the destination value *is* the view. Push or present the value; SwiftUI (or Navigator) evaluates its `body` to get the screen.
- Define an enum with a case per screen; use **associated values** to pass parameters (e.g. `case pageN(Int)`).
- Implement `body` with a `switch self` that returns the correct view for each case.

```swift
nonisolated public enum HomeDestinations: NavigationDestination {
    case home(String)
    case page2
    case page3
    case pageN(Int)

    public var body: some View {
        switch self {
        case .home(let title):
            HomeContentView(title: title)
        case .page2:
            HomePage2View()
        case .page3:
            HomePage3View()
        case .pageN(let value):
            HomePageNView(number: value)
        }
    }
}
```

## Environment and dependencies

When views need **environment values** or **dependency injection**, do not put that logic in the enum's `body` (enums have limited access to environment). Instead, **delegate to a private SwiftUI View** that has full access to `@Environment`:

1. In the enum: `public var body: some View { HomeDestinationsView(destination: self) }`
2. Implement a private `HomeDestinationsView: View` that takes `let destination: HomeDestinations` and `@Environment(\.homeDependencies) var resolver` (or similar), then switch on `destination` and build views using `resolver`.

Callers only see the enum; they never see the private view or the resolver. This keeps dependencies and view models internal and supports the coordination pattern.

## Destination as view in sheets/covers

Because the enum conforms to View, you can use it directly in a sheet or fullScreenCover:

```swift
@State private var present: AccountDestinations?

.sheet(item: $present) { destination in
    destination   // the value is a view
}
```

Set `present = .details(account)` to present. If the sheet is presented **outside** Navigator's `navigate(to:)`, wrap the content in **ManagedPresentationView** or **.managedPresentationView()** so Navigator can dismiss it (see [Dismissible.md](Dismissible.md)).

## Using an explicit destination as root content

You can use a destination value as the initial content of a stack (e.g. "home" as the root screen):

```swift
ManagedNavigationStack {
    HomeDestinations.home
}
```

The enum is a View, so it renders like any other view. No need for a separate root view type if a destination case represents the root.

## External / cross-module views

When a feature needs a view provided by another module (e.g. "external" screen), the destination view can obtain it from a dependency resolver in the environment (e.g. `resolver.externalView()`). The app composes a resolver that returns the appropriate view (e.g. from another module's destination). The feature module never imports the other module; it only depends on the resolver protocol. Alternatively use **NavigationProvidedDestination** and **onNavigationProvidedView** for full modular provision (see [ProvidedDestinations.md](ProvidedDestinations.md)).

## Coordination pattern

Destinations support the coordination pattern: callers specify *where* to go (the enum case); they do not specify *which* view type or how it is built. The destination enum owns that knowledge. Use `NavigationLink(to: Destination.case)` or `navigator.navigate(to: Destination.case)`; the destination's `body` supplies the view.
