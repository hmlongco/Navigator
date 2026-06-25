# Destinations

All navigation in Navigator is accomplished using enumerated values that conform to the NavigationDestination protocol.

## Overview

NavigationDestination types can be used in order to push and present views as needed.

This can happen using…

* Special SwiftUI modifiers like NavigationLink(to:label:).
* Imperatively by asking a Navigator to perform the desired action.
* Or via a deep link action enabled by a NavigationRoute or NavigationURLHander.

They’re one of the core elements that make Navigator possible, and they give us the separation of concerns we mentioned earlier.

### Defining Navigation Destinations
Destinations (or routes) are typically just public lists of enumerated values, one for each view desired.
```swift
nonisolated public enum HomeDestinations {
    case page2
    case page3
    case pageN(Int)
}
```
SwiftUI requires navigation destination values to be `Hashable`, and so do we. That conformance, however, is satisfied by
conforming to the protocol NavigationDestination as shown next. 

### Defining Destination Views
Defining our destination views is easy, since NavigationDestination actually conforms to the View protocol! 

As such, we just provide our enumeration with a view body that returns the correct view for each case.
```swift
    ...
    case pageN(Int)

    public var body: some View {
        switch self {
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
This is a powerful technique that lets Navigator easily create our views whenever or wherever needed. That could be via `NavigationLink(to:label)`, or presented via a sheet or fullscreen cover.

Note how associated values can be used to pass parameters to views as needed.

> Info: To build more complex views that have external dependencies or that require access to environmental values, see <doc:AdvancedDestinations>.

### Managed Navigation Stacks

The next step towards using Navigator is to use `ManagedNavigationStack` when you once used `NavigationStack` in your code.
```swift
struct RootView: View {
    var body: some View {
        ManagedNavigationStack {
            List {
                NavigationLink(to: HomeDestinations.page3) {
                    Text("Link to Page 3!")
                }
            }
        }
    }
}
```
It's that simple.

For text-only links, skip the trailing closure. As of Navigator 2.1.2, `NavigationLink` accepts the title directly alongside the destination, with the title given as a plain string, a `LocalizedStringKey`, or a `LocalizedStringResource`.
```swift
NavigationLink("Link to Page 3!", to: HomeDestinations.page3)
```

ManagedNavigationStack creates a NavigationStack for you and installs the associated Navigator environment variable that "manages" that particular NavigationStack. It provides it with the NavigationPath and also supports navigation options like automatically presenting sheets and fullScreenCovers.

Those with sharp eyes might have noticed something missing in the above code. We're using `NavigationLink` with a destination value, but where's the `.navigationDestination(for: HomeDestinations.self) { ... )` modifier?

Or, as done in earlier versions of Navigator, the `.navigationDestination(HomeDestinations.self)` modifier?

As of Navigator 1.2.0, there's no need for them. 

Seriously.

### Eliminating Navigation Destination Registrations

As you're no doubt aware, SwiftUI's `NavigationStack` requires destination types to be registered in order 
for `NavigationLink(value:label:)` transitions to work correctly.

But that seems redundant, doesn't it? Our NavigationDestination enumerations *already* define the views to be provided, so why is registration needed? 

Turns out that it's not! 

Just use `NavigationLink(to:label)` instead of `NavigationLink(value:label)` in your code and let Navigator handle the rest:

```swift
import NavigatorUI

struct SettingsTabView: View {
    var body: some View {
        ManagedNavigationStack {
            List {
                NavigationLink(to: ProfileDestinations.main) {
                    Text("User Profile")
                }
                NavigationLink(to: SettingsDestinations.main) {
                    Text("Settings")
                }
                NavigationLink(to: AboutDestinations.main) {
                    Text("About Navigator")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
```
Here we use three different NavigationDestination types, but provide no registrations.

So what black magic is this? Simple. Navigator provides an initializer for `NavigationLink` that takes `NavigationDestination` types and maps them to an internal type that `ManagedNavigationStack` has already registered for you.

This small change allows a single `navigationDestination` handler to push `NavigationDestination` views of *any* type!

Consider a modular application whose home screen uses "cards" provided from different modules. Clicking on a card from Module A should push an internal view from that module... but that's only possible if we somehow knew how to register the needed types from module A.

Now there's no need to do so!

To reiterate.

```swift
// DO
NavigationLink(to: HomeDestinations.page3) {
    Text("Link to Home Page 3!")
}

// DON'T DO
NavigationLink(value: HomePage3View()) {
    Text("Link to Home Page 3!")
}
```
Note that this is *potentially* a breaking change in your code and from earlier versions of Navigator. Use the old `NavigationLink(value:label)` view *without* registering the destination and navigation will fail. 

Switch to using `NavigationLink(to:label)` and you'll be fine. 

> Info: If for some reason you prefer or need the registration mechanism to support older code, don't worry. Just continue to use `NavigationLink(value:label:)` and `navigationDestination` registrations just like you did before.

### Programatic Navigation Destinations
Navigation Destinations can also be dispatched programmatically via Navigator, or declaratively using modifiers.
```swift
// Sample using optional destination
@State var page: SettingsDestinations?
...
Button("Modifier Navigate to Page 3!") {
    page = .page3
}
.navigate(to: $page)

// Sample using trigger value
@State var triggerPage3: Bool = false
...
Button("Modifier Trigger Page 3!") {
    triggerPage3.toggle()
}
.navigate(trigger: $triggerPage3, destination: SettingsDestinations.page3)
```
Or imperatively by asking a Navigator to perform the desired action.
```swift
@Environment(\.navigator) var navigator: Navigator
...
Button("Button Navigate To Home Page 55") {
    navigator.navigate(to: HomeDestinations.pageN(55))
}
Button("Button Push Home Page 55") {
    navigator.push(HomeDestinations.pageN(55))
}
```
In case you're wondering, calling `push` pushes the associated view onto the current `NavigationStack`, while `navigate(to:)` will push the view or present the view, based on the `NavigationMethod` specified.

### Navigation Methods

`NavigationDestination` can be extended to provide a distinct ``NavigationMethod`` for each enumerated type.
```swift
extension HomeDestinations: NavigationDestination {
    public var method: NavigationMethod {
        switch self {
        case .page2:
            .sheet
        case .page3:
            .managedSheet
        default:
            .push
        }
    }
}
```
In this case, should `navigator.navigate(to: HomeDestinations.page3)` be called, Navigator will automatically present that view in a
sheet. All other views will be pushed onto the navigation stack.

The current navigation methods are: `.push` (default), `.sheet`, `.managedSheet`, `.cover`, `.managedCover`, and `.send`.

As you might expect, the `.sheet` and `.cover` methods launch sheets and fullScreenCovers, respectively. The `.managedSheet` and `.managedCover` variants do the same, while also wrapping the destination in a `ManagedNavigationStack` for you. 

Just as if you'd done...
```swift
    public var body: some View {
        switch self {
        ...
        case .page3:
            ManagedNavigationStack { // not needed with .managedSheet
                HomePage3View()
            }
        ...
        }
    }
}
```
Specifying `.managedSheet` and `.managedCover` methods instead of explicitly wrapping the code with navigation views make your views more flexible.

And if you need to change do something different at some point, predefined methods can always be overridden using Navigator's `navigate(to:method:)` function.

```swift
Button("Present Home Page 55 Via Sheet") {
    navigator.navigate(to: HomeDestinations.page3, method: .sheet)
}
```
> Important: Note that NavigationDestinations dispatched via NavigationLink will *always* push onto the NavigationStack. That's just how SwiftUI works.

### Values, Not Destinations

Navigator is designed to work with ``NavigationDestination`` types and SwiftUI's `NavigationLink(value:label:)`; not `NavigationLink(destination:label:)`.

Mixing the two on the same `NavigationStack` can lead to unexpected behavior, and using `NavigationLink(destination:label:)` at all can affect programatic navigation using Navigators. 

```swift
// DO
NavigationLink(to: HomeDestinations.page3) {
    Text("Link to Home Page 3!")
}

// DON'T DO
NavigationLink(destination: HomePage3View()) {
    Text("Link to Home Page 3!")
}
```
If you start seeing odd behavior returning to previous views, check to make sure a `NavigationLink(destination:label:)` link hasn't worked its way into your code.

> IMPORTANT: Use `Navigation(to:label:)`. Avoid using `NavigationLink(destination:label:)`.

## See Also

- <doc:AdvancedDestinations>
