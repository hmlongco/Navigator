# Navigation Provided Destinations

Creating and using NavigationDestination's when you don't know the destination.

## Overview

NavigationDestination's are a powerful concept, but they require the destination to provide the views needed as part of the protocol. 

And in many cases that's not a problem.

```swift
nonisolated public enum SharedDestinations: NavigationDestination {
    case newOrder
    case orderDetails(Order)
    case produceDetails(Product)

    public var body: some View {
        switch self {
        case .newOrder:
            NewOrderView()
        case .orderDetails(let order):
            OrderDetailsView(order)
        case .produceDetails(let product):
            ProduceDetailsView(for: product)
        }
    }
}
```
But what happens when that information isn't available? Or can't be seen? This is a chicken and egg situation that's extremely common in modern modular applications.

To illustrate, what if our `SharedDestinations` enumeration wants to live in a `Shared` module in our application, imported so that any module in our application can see it and use it?

Fine. Just define it there.
```swift
nonisolated public enum SharedDestinations: NavigationDestination {
    case newOrder
    case orderDetails(Order)
    case produceDetails(Product)

    public var body: some View {
        ???
    }
}
```
Except... the problem is that `NavigationDestination` is expected to provide a View body that returns the destination views for each of those cases... but the Shared module can't *see* those views. It knows nothing about them.

The `Order` and `Product` modules import `Shared`, not the other way around. Nor do we want to create a module that does so.

NavigationProvidedDestination provides the solution.

### NavigationProvidedDestination

Just change the destination type to be `NavigationProvidedDestination`.

```swift
nonisolated public enum SharedDestinations: NavigationProvidedDestination {
    case newOrder
    case orderDetails(Order)
    case produceDetails(Product)
}
```
And you're good to go. 'NavigationProvidedDestination provides a custom view body that promises to provide the views in question.

But... how?

It asks Navigator for them, of course.

### Registering Provided Destinations

But that just kicks the can down the road. *Where does Navigator get them from?*

The application, of course. It registers them using a new modifier: `onNavigationProvidedView`.

```swift
import Shared
import Orders
import Products
import NavigatorUI
import SwiftUI

struct ContentView: View {
    let navigator: Navigator = .init(configuration: .init())
    var body: some View {
        RootTabView()
            // provide Shared views
            .onNavigationProvidedView(SharedDestinations.self) {
                switch $0 {
                case .newOrder:
                    NewOrderView()
                case .orderDetails(let order:
                    OrderDetailsView(order)
                case .produceDetails(let product):
                    ProductDestinations.details(product)
                }
            }
            // setup managed navigation root
            .navigationRoot(navigator)
    }
}
```
In effect, it's just another version of `navigationDestination(for:)`, a concept borrowed and updated for our purposes.

After all, it's the app that sees all and knows all. And in this case, it's also trusted to provide all.

The application knows about the `Orders` and `Products` modules, and it and only it can see into them to get the public views needed. 

And in the case of the `Products` module, it can't even see the views. It just asks `ProductDestinations` to provide what's needed. (ProductDestinations is a `NavigationDestination` type.)

>Note: This concept works hand in hand with the concept of NavigationDestination auto-registration developed for Navigator 1.2. One can get and present a new orders view or product view without caring what views that view may push or present.

### Exposed Destinations

This system works well for shared dependencies, but it can also be useful to let a module expose a custom set of external view dependencies.

```swift
nonisolated public enum OrdersExternalViews: NavigationProvidedDestination {
    case homeAddressEntryScreen
}
```
Here the `Orders` module is basically saying, "Hey, I may want to show the screen that lets the user enter his home address. Somebody needs to give it me."

With that someone being the application, of course.
```swift
.onNavigationProvidedView(OrdersExternalViews.self) { _ in
    ProfileDestinations.addressEntry // only one view, so no switch needed
}
```
This makes it much, much easier to create modular applications that minimizes the known dependencies between modules. Use shared dependencies for common cases, and custom external dependencies when and where needed.

The alternative is for module A to import module B and vice-versa... and that tends to eliminate most the benefits we gained from modularization in the first place.

### NavigationProvidedView

If one were to look at the view body provided for `NavigationProvidedDestination` you'd see the following:

```swift
extension NavigationProvidedDestination {
    public var body: some View {
        NavigationProvidedView(for: self)
    }
}
```
`NavigationProvidedDestination` just punts and calls `NavigationProvidedView`. Digging further, we'd see that the relevant portion of `NavigationProvidedDestination` looks like this.
```swift
public struct NavigationProvidedView<D: NavigationDestination, P: View>: View {
    @Environment(\.navigator) private var navigator
    ...
    public var body: some View {
        if let view = navigator.navigationProvidedView(for: destination) {
            AnyView(view)
        } else if let placeholder {
            placeholder
        } else {
            #if DEBUG
            Text(verbatim: "Missing Provider for \(type(of: self)).\(self)")
            #else
            EmptyView()
            #endif
        }
    }
}
```
Simply put, and as mentioned earlier, `NavigationProvidedView` is just a view that knows how to ask Navigator to find the correct view for that type. 

If no navigation provided destination is found then the view returns a placeholder view. And if no placeholder is found, it returns `EmptyView` in production mode, but something a bit more informative when running in `DEBUG` mode.

But... what's a placeholder?

### Placeholder Views

As one might expect, it's just a way to provider our own custom placeholder views for our own types if we so desire. Consider this potential implementation of `SharedDestinations`.
```swift
nonisolated public enum SharedDestinations: NavigationDestination {
    case newOrder
    case orderDetails(Order)
    case produceDetails(Product)

    public var body: some View {
        NavigationProvidedView(for: self) {
            switch self {
            case .newOrder:
                MockNewOrderView()
            case .orderDetails(let order):
                MockOrderDetailsView(order)
            case .produceDetails(let product):
                MockProduceDetailsView(for: product)
            }
        }
    }
}
```
One could also follow the behavior of `NavigationProvidedView`, returning mocks in DEBUG mode and launch an "Oops!" page so your users could tell you that something is awry should this code somehow make it into production.

It's up to you.

>Note: Not knowing if a view is registered may seem scary, but in reality we're just mimicking the behavior of `NavigationLink(value:label:)` or `NavigationPath` when a unknown type is pushed and we see an empty view. Sometimes you just have to trust the app.

### Single Views

Thus far we seen `NavigationProvidedView` used to manage replacements for entire types. But one can also use it to provide single views when needed. Consider:

```swift
nonisolated public enum HomeDestinations: NavigationDestination {
    ...
    case pageN(Int)
    case external

    var body: some View {
        switch select {
        ...
        case .pageN(let n):
            HomePageNView(number: n)
        case .external:
            NavigationProvidedView(for: HomeDestinations.external)
        }
    }
}
```
Here we provide known views for most of our cases. But for `external` we ask the application to provide it for us.
```swift
.onNavigationProvidedView(HomeDestinations.self) { destination in
    switch destination {
    case .external:
        SomeExternalView()
    default:
        EmptyView()
    }
}
```
Note that in the default we're seemingly return EmptyView for all of the other cases, but that's just to make the compiler happy. All of the other cases would have been caught and handled earlier in the original `switch` statement.

All in all, use this particular technique judiciously. As we saw earlier it's usually better for a module to expose a custom enumeration explicitly exposed and defined to manage external view dependencies.

### Dependency Injection and NavigationViewProviding

One final technique that's completely different but worth mentioning uses the `NavigationViewProviding` protocol. Effectively, you're going to force your application's dependency injection system to give you what you need.

Let's look at a portion of our dependency requirements for our "Home" module.
```swift
public protocol HomeDependencies {
    ...
    @MainActor var homeExternalViewProvider: any NavigationViewProviding<HomeExternalViews> { get }
    ...
}
```
This tells the application that it *must* return something that conforms to `NavigationViewProviding`, which is simply a protocol that promises to return a view for a given type when asked.
```swift
public protocol NavigationViewProviding<D> {
    associatedtype D: NavigationViews
    func view(for destination: D) -> AnyView
}
```
In this case, our `HomeExternalViews` enumeration conforms to `NavigationViews` (basically just `Hashable`).
```swift
nonisolated public enum HomeExternalViews: NavigationViews {
    case external
}
```
So when the application constructs our module's dependencies, it's forced to give us what we need.
```swift
// Home needs an external view from somewhere. Provide it.
public class AppResolver: AppDependencies, HomeDependencies, ...  {
    ...
    @MainActor public var homeExternalViewProvider: any NavigationViewProviding<HomeExternalViews> {
        NavigationViewProvider {
            switch $0 {
            case .external:
                SettingsDestinations.external
            }
        }
    }
}
```
All of which lets us finally access the view needed in `HomeDestinations`.
```swift
internal struct HomeDestinationsView: View {
    // Selected destination to display
    let select: HomeDestinations
    // Obtain home dependency resolver
    @Environment(\.homeDependencies) var resolver
    // Standard view body
    var body: some View {
        switch select {
        ...
        case .external:
            resolver.homeExternalViewProvider.view(for: .external)
        ...
    }
}
```
The module described its dependencies, the application provided them, and the view accessed them. And in this case we *know* we have what we need.

That said, it's a lot easier to use `NavigationProvidedDestination` and eliminate all of the extra boilerplate and moving parts.

One enumeration on one side, one registration on the other side, and you're done.
