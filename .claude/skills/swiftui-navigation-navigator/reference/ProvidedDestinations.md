# Provided destinations (reference)

In **modular apps**, a shared module may define navigation destinations that it cannot implement itself because the actual views live in other modules (e.g. app or feature modules). **NavigationProvidedDestination** and **onNavigationProvidedView** let the shared module declare the cases; the **app** (or a layer that sees all modules) provides the views.

## NavigationProvidedDestination

Conform an enum to **NavigationProvidedDestination** instead of **NavigationDestination** when the module cannot see the view types:

```swift
// In a Shared / Common module
nonisolated public enum SharedDestinations: NavigationProvidedDestination {
    case newOrder
    case orderDetails(Order)
    case produceDetails(Product)
}
```

The protocol provides a default **body** that uses **NavigationProvidedView(for: self)** to resolve the view at runtime. No view body is implemented in the module; the app will provide it.

## Registering provided views

At the **app root** (or wherever you have access to all modules), register the views for that type **before** **`.navigationRoot(navigator)`**:

```swift
RootTabView()
    .onNavigationProvidedView(SharedDestinations.self) {
        switch $0 {
        case .newOrder:
            NewOrderView()
        case .orderDetails(let order):
            OrderDetailsView(order)
        case .produceDetails(let product):
            ProductDestinations.details(product)
        }
    }
    .navigationRoot(navigator)
```

Navigator looks up the provider by the destination's type; when a `SharedDestinations` value is pushed or presented, it asks the provider for the view. The app sees all modules and can return the correct view for each case.

## NavigationProvidedView and placeholders

- **NavigationProvidedView(for: self)** is used internally by the default `NavigationProvidedDestination` body. It asks the navigator (root) for a view for that destination; if none is registered, it can show a **placeholder** or (in debug) a "missing provider" message.
- You can use **NavigationProvidedView(for: destination) { placeholderView }** when you want a custom placeholder when no provider is registered (e.g. a mock or loading view).

## Single-case provision

A destination enum can mix provided and non-provided cases: implement **body** with a switch, and for the "external" case use **NavigationProvidedView(for: self)** or **NavigationProvidedView(for: Self.external) { placeholder }**. Register with **onNavigationProvidedView(YourDestinations.self)** and in the switch return a view only for the external case; for other cases return `EmptyView()` to satisfy the compiler (they are handled in the body switch).

## NavigationViewProviding (alternative)

For dependency-injection style provision, a module can declare a dependency on **NavigationViewProviding<SomeEnum>**. The app supplies an object that conforms to that protocol (e.g. a **NavigationViewProvider** built with a closure). The module then calls **provider.view(for: .case)** to get the view. This is more boilerplate than **NavigationProvidedDestination** + **onNavigationProvidedView**; use the latter when you want one enum and one registration at the root.
