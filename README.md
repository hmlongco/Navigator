[![swift-versions](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fhmlongco%2FNavigator%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/hmlongco/Navigator)
[![platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fhmlongco%2FNavigator%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/hmlongco/Navigator)
![License](https://img.shields.io/badge/License-MIT-brown.svg)

![](https://github.com/hmlongco/Navigator/blob/main/Logo.png?raw=true)

Advanced Navigation Support for SwiftUI.

## Navigator 1.4.5

Navigator provides SwiftUI with a simple yet powerful navigation layer based on NavigationStack. 

This is *not* just another push/pop navigation stack library. It supports...

* Simple and easy navigation linking and presentation of views.
* Coordination patterns with well-defined separation of concerns. 
* Extensive support for modular applications including cross-module navigation and views.
* True deep linking and internal application navigation via navigation send.
* Easily returning to a specific spot in the navigation tree via navigation checkpoints.
* Returning callback values via navigation checkpoints.
* Both Declarative and Imperative navigation and control.
* Navigation state restoration.
* Event logging and debugging.
* No navigationDestination registration operations are required.

You might want to reread that last bullet point again...

Navigator is written entirely in Swift and SwiftUI, and supports iOS 16 and above.

## The Code

### Defining Navigation Destinations
Destinations (or routes) are typically just public lists of enumerated values, one for each view desired.
```swift
nonisolated public enum HomeDestinations: NavigationDestination {

    case page2
    case page3
    case pageN(Int)
    
}
```
SwiftUI requires navigation destination values to be `Hashable`, and so do we. 

With our enum in place, we now need to provide each destination with a variable that returns the correct view for each case. That's easy, since `NavigationDestination` also conforms to `View`! 

Just provide the view body as part of the enumeration.
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
Note how associated values can be used to pass parameters to views as needed.

*To build views that have external dependencies or that require access to environmental values, see ``Advanced Destinations`` below.*

### Managed Navigation Stacks

The next step is to use `ManagedNavigationStack` when you once used `NavigationStack` in your code.
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

Note that this is *potentially* a breaking change. Use the old `NavigationLink(value:label)` view *without* defining the destination and navigation will fail. 

Use `NavigationLink(to:label)` and you'll be fine.

*If you prefer or need the registration mechanism to support older code, don't worry. Just continue to use `NavigationLink(value:label:)` and `navigationDestination` registrations just like you did before.*

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
In case you're wondering, calling `push` pushes the associated view onto the current `NavigationStack`, while `navigate(to:)` will push the view or present the view, based on the `NavigationMethod` specified (coming up next).

### Navigation Methods

Your `NavigationDestination` type can be extended to provide a distinct ``NavigationMethod`` for each enumerated type.
```swift
extension HomeDestinations {
    public var method: NavigationMethod {
        switch self {
        case .page3:
            .sheet
        default:
            .push
        }
    }
}
```
In this case, should `navigator.navigate(to: HomeDestinations.page3)` be called, Navigator will automatically present that view in a sheet. All other views will be pushed onto the navigation stack.

The current navigation methods are: .push (default), .sheet, .managedSheet, .cover, .managedCover, and .send.

Predefined methods can be overridden using Navigator's `navigate(to:method:)` function.

```swift
Button("Present Home Page 55 Via Sheet") {
    navigator.navigate(to: HomeDestinations.pageN(55), method: .sheet)
}
```
*Note that destinations dispatched via NavigationLink will always push onto the NavigationStack. That's just how SwiftUI works.*

### Checkpoints

Like most systems based on NavigationStack, Navigator supports operations like popping back to a previous view, dismissing a presented view, and so on.
```swift
Button("Pop To Previous Screen") {
    navigator.pop()
}
Button("Dismiss Presented View") {
    navigator.dismiss()
}
```
But those are all imperative operations. While one can programmatically pop and dismiss their way out of a screen, that approach is problematic and tends to be fragile. One could pass bindings down the tree, but that can also be cumbersome and difficult to maintain.

Fortunately, Navigator supports checkpoints; named points in the navigation stack to which one can easily return.

Checkpoints are easy to define and use. Let's create one called "home" and then use it.
```swift
struct KnownCheckpoints: NavigationCheckpoints {
    public static var home: NavigationCheckpoint<Void> { checkpoint() }
}

struct RootHomeView: View {
    var body: some View {
        ManagedNavigationStack(scene: "home") {
            HomeContentView(title: "Home Navigation")
                .navigationCheckpoint(KnownCheckpoints.home)
        }
    }
}
```
Once defined, they're easy to use.
```swift
Button("Return To Checkpoint Home") {
    navigator.returnToCheckpoint(KnownCheckpoints.home)
}
.disabled(!navigator.canReturnToCheckpoint(KnownCheckpoints.home))
```
When fired, checkpoints will dismiss any presented screens and pop any pushed views to return *exactly* to the point desired.

One might ask why we needed to add `<Void>` to our original checkpoint definition?

That's because checkpoints can also be used to return values to a caller!
```swift
// Define a checkpoint with an Int value handler.
extension KnownCheckpoints {
    public static var settings: NavigationCheckpoint<Int> { checkpoint() }
}

// Establish the checkpoint and handler in our view
.navigationCheckpoint(KnownCheckpoints.settings) { result in
    returnValue = result
}

// Return, passing a value.
Button("Return to Settings Checkpoint Passing Value 5") {
    navigator.returnToCheckpoint(KnownCheckpoints.settings, value: 5)
}
```
Checkpoints are a powerful tool. Use them.

### Deep Linking Support

Navigator supports external deep linking and internal application navigation via navigation send.

This comes in handy when navigation means needing to change non-NavigationStack-based values like the selected tab, or perhaps an account number used to trigger the detail view in a `NavigationSplitView`.

Consider the following fairly standard RootTabView.
```swift
struct RootTabView : View {
    @SceneStorage("selectedTab") var selectedTab: RootTabs = .home
    var body: some View {
        TabView(selection: $selectedTab) {
            RootHomeView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(RootTabs.home)
            RootSettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(RootTabs.settings)
        }
        .onNavigationReceive { (tab: RootTabs) in
            if tab == selectedTab {
                return .immediately
            }
            selectedTab = tab
            return .auto
        }
    }
}
```
Sharp eyes may have spotted the `onNavigationReceive` modifier, which--much like `navigationDestination(MyType.self)`--is listening for Navigator to broadcast a value of type RootTabs.

When received, Navigator will dismiss any presented screens, set the selected tab, and then return normally.

Values are broadcast using `navigationSend()` as shown below.
```swift
Button("Send Tab Home, Page 2") {
    navigator.send(
        RootTabs.home,
        HomeDestinations.page2
    )
}
```
The `RootTabs` receiver switches to the selected tab, and then a similar `HomeDestinations` receiver sends the user to page 2.
```swift
.onNavigationReceive { (destination: HomeDestinations, navigator) in
    navigator.navigate(to: destination)
    return .auto
}
```
This mechanism makes deep linking and internal navigation support simple and easy.

Note that some of the above sequences are so common there are shortcuts to support them.
```swift
struct RootTabView : View {
    @SceneStorage("selectedTab") var selectedTab: RootTabs = .home
    var body: some View {
        TabView(selection: $selectedTab) {
            ...
        }
        .onNavigationReceive(assign: $tab) // shortcut
    }
}

struct RootHomeView: View {
    var body: some View {
        ManagedNavigationStack(scene: "home") {
            HomeContentView(title: "Home Navigation")
                .navigationAutoReceive(HomeDestinations.self) // shortcut
        }
    }
}
```

Both of the above perform identically to the examples shown previously.

### Advanced Destinations

What if we can't construct a specific view without external dependencies or without accessing the environment? 

Simple. Just delegate the view building to a standard SwiftUI view!
```swift
nonisolated public enum HomeDestinations: NavigationDestination {
    ...
    public var body: some View {
        HomeDestinationsView(destination: self)
    }
}

private struct HomeDestinationsView: View {
    let destination: HomeDestinations
    @Environment(\.homeDependencies) var resolver
    var body: some View {
        switch self {
        case .home:
            HomePageView(viewModel: HomePageViewModel(dependencies: resolver))
        case .page2:
            HomePage2View(viewModel: HomePage2ViewModel(dependencies: resolver))
        case .page3:
            HomePage3View(viewModel: HomePage3ViewModel(dependencies: resolver))
        case .pageN(let value):
            HomePageNView(viewModel: HomePageNViewModel(dependencies: resolver), number: value)
        }
    }
}
```
In the above code, we obtain a `homeDependencies` resolver from the environment, then use it to construct our views
and view models.

Note this technique can be used to construct and use fully functional views elsewhere in your view code. Consider.
```swift
struct RootHomeView: View {
    var body: some View {
        ManagedNavigationStack(scene: "home") {
            HomeDestinations.home
        }
    }
}
```
Calling the destination as a function obtains a fully resolved `HomePageView` and view model from `HomeDestinationsView`, 
complete and ready to go.

Check out the NavigatorDemo project for a more thorough example of this dependency injection mechanism.

### Modular Applications

NavigationDestination works well for situations where the required views can be seen and defined in the destination's view body. But what happens in modular applications when that information is **not** available to the module in question?

Just define your destinations as conforming to `NavigationProvidedDestination`. 

Consider an application that wants to provide feature modules with a list of views that they can use and present. Just put the following destination in a `Shared` or `Common` module.
```swift
nonisolated public enum SharedDestinations: NavigationProvidedDestination {
    case newOrder
    case orderDetails(Order)
    case produceDetails(Product)
}
```
Conforming to `NavigationProvidedDestination` tells Navigator (and Swift) that the missing destinations will be provided elsewhere in the application.

Then in your application root, simply register and provide the missing dependencies for that type.
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
This works because the application sees all and knows all and as such it can provide the missing views from the 'Orders' and 'Products' module.

See the [documentation](https://hmlongco.github.io/Navigator/documentation/navigatorui/provideddestinations) for more.

## Documentation

A single README file barely scratches the surface. Fortunately, Navigator is fairly well documented, with more to come. 

See [Navigator Documentation](https://hmlongco.github.io/Navigator/documentation/navigatorui/).

Also see Additional Resources section below.

## Installation

Navigator supports the Swift Package Manager.

Or download the source files and add the Navigator folder to your project.

Then `import NavigatorUI` into your project where needed.

Note that the current version of Navigator requires Swift 5.10 minimum and that the minimum version of iOS currently supported with this release is iOS 16.

## Discussion Forum

Discussion and comments on Navigator can be found in [Discussions](https://github.com/hmlongco/Navigator/discussions). Go there if you have something to say or if you want to stay up to date.

## License

Navigator is available under the MIT license. See the LICENSE file for more info.

## Sponsor Navigator!

If you want to support my work on Navigator, Factory and my other open source projects, consider a [GitHub Sponsorship](https://github.com/sponsors/hmlongco)! Many levels exist for increased support and even for mentorship and company training. 

Or you can just buy me a cup of coffee!

## Author

Navigator is designed, implemented, documented, and maintained by [Michael Long](https://www.linkedin.com/in/hmlong/), a Lead iOS Software Engineer and a Top 1,000 Technology Writer on Medium.

* LinkedIn: [@hmlong](https://www.linkedin.com/in/hmlong/)
* Medium: [@michaellong](https://medium.com/@michaellong)
* BlueSky: [@hmlongco](https://bsky.app/profile/hmlongco.bsky.social)

Michael was also one of Google's [Open Source Peer Reward](https://opensource.googleblog.com/2021/09/announcing-latest-open-source-peer-bonus-winners.html) winners in 2021 for his work on Resolver.

## Additional Resources

* [Medium: Advanced Navigation Destinations in SwiftUI](https://michaellong.medium.com/advanced-navigation-destinations-in-swiftui-05c3e659f64f?sk=030440d95749f5adc6d2b43ca26baee1)
* [Medium: Advanced Deep Linking in SwiftUI](https://michaellong.medium.com/advanced-deep-linking-in-swiftui-c0085be83e7c?sk=118d08a22cb02b21dccf9235d78dc74f)
* [Medium: Navigation Checkpoints in SwiftUI](https://michaellong.medium.com/navigation-checkpoints-in-swiftui-345270388240?sk=a7802f5351fcb3b5cfced714d0bcfaec)
* [Medium: SwiftUI Navigation With Dismissible](https://michaellong.medium.com/swiftui-navigation-with-dismissible-8de3cab72a4e?sk=dcb743fbb90d59c5775fed33725958b9)
* [Medium: Eliminating Navigation Registrations in SwiftUI] (https://medium.com/the-swift-cooperative/swiftui-eliminating-navigation-registration-7339691c2887?sk=583c8b1fdc7945501f707ea94020737f)
* [Medium: Now Previewing Navigator!](https://michaellong.medium.com/now-previewing-navigator-faebf290a1da?sk=88d3ff52057cf0a948279e6be4a15f75)
* [Navigator Documentation](https://hmlongco.github.io/Navigator/documentation/navigatorui/)
* [Factory](https://hmlongco.github.io/Factory/)
