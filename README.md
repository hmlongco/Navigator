# Navigator

Advanced Navigation Support for SwiftUI.

## Introduction

Navigator provides SwiftUI with a simple yet powerful navigation layer based on NavigationStack. 

It supports...

* Simple and easy navigation linking and presentation of views.
* Coordination patterns with well-defined separation of concerns. 
* External deep linking and internal application navigation via navigation send.
* Easily returning to a specific spot in the navigation tree via navigation checkpoints.
* Returning callback values via navigation checkpoints.
* Both Declarative and Imperative navigation and control.
* Navigation state restoration.
* Event logging and debugging.

Navigator is written entirely in Swift and SwiftUI, and supports iOS 16 and above.

## The Code

### Defining Navigation Destinations
Destinations (or routes) are typically just public lists of enumerated values, one for each view desired.
```swift
public enum HomeDestinations {
    case page2
    case page3
    case pageN(Int)
}
```
SwiftUI requires navigation destination values to be `Hashable`, and so do we.

Next, we extend each destination with a variable that returns the correct view for each case.
```swift
extension HomeDestinations: NavigationDestination {
    public var view: some View {
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

### Registering Navigation Destinations
Like traditional `NavigationStack` destination types, `NavigationDestination` types need to be registered with the enclosing
navigation stack in order for `navigate(to:)` presentations and standard `NavigationLink(value:label:)` transitions 
to work correctly.

But since each `NavigationDestination` already defines the views to be provided, registering destination types can be done
using a simple one-line view modifier.
```swift
ManagedNavigationStack {
    HomeView()
        .navigationDestination(HomeDestinations.self)
}
```
This also makes using the same destination type with more than one navigation stack a lot easier.

### Using Navigation Destinations
With that out of the way, Navigation Destinations can be dispatched using a standard SwiftUI `NavigationLink(value:label:)` view.
```swift
NavigationLink(value: HomeDestinations.page3) {
    Text("Link to Home Page 3!")
}
```
Or they can be dispatched declaratively using modifiers.
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
Button("Button Push Home Page 55") {
    navigator.navigate(to: HomeDestinations.pageN(55))
}
Button("Present Home Page 55 Via Sheet") {
    navigator.navigate(to: HomeDestinations.pageN(55), method: .sheet)
}
```
### Navigation Methods
`NavigationDestination` can also be extended to provide a distinct ``NavigationMethod`` for each enumerated type.
```swift
extension HomeDestinations: NavigationDestination {
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
In this case, should `navigator.navigate(to: HomeDestinations.page3)` be called, Navigator will automatically present that view in a
sheet. All other views will be pushed onto the navigation stack.

The current navigation methods are: .push, .sheet, .cover, and .send.

*Note that destinations dispatched via NavigationLink will always push onto the NavigationStack. That's just how SwiftUI works.*

### Dismissing Presented Views

*Introduction coming soon, in the meantime, see Demo project for examples.*

### Checkpoints

*Introduction coming soon, in the meantime, see Demo project for examples.*

### Deep Linking Support

*Introduction coming soon, in the meantime, see Demo project for examples.*

### Advanced Destinations

What if we can't construct a specific view without external dependencies or without accessing the environment? 

Simple. Just delegate the view building to a standard SwiftUI view!
```swift
extension HomeDestinations: NavigationDestination {
    public var view: some View {
        HomeDestinationsView(destination: self)
    }
}

private struct HomeDestinationsView: View {
    let destination: HomeDestinations
    @Environment(\.coreDependencies) var resolver
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
In the above code, we obtain a `coreDependencies` resolver from the environment, and then use it to construct our views
and view models.

Note this technique can be used to construct fully functional views elsewhere in your view code. Consider.
```swift
struct RootHomeView: View {
    var body: some View {
        ManagedNavigationStack(scene: "home") {
            HomeDestinations.home()
                .navigationDestination(HomeDestinations.self)
        }
    }
}
```
Calling the destination as a function obtains a fully resolved `HomePageView` from `HomeDestinationsView`, complete and ready to go.

See the 'DemoDependency.swift' file in the NavigatorDemo project for a possible dependency injection mechanism.

## Documentation

A single README file barely scratches the surface. Fortunately, Navigator is throughly documented. 

Current DocC documentation can be found in the project.

## Installation

Navigator supports the Swift Package Manager.

Or download the source files and add the Navigator folder to your project.

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

* [Factory](https://hmlongco.github.io/Factory/)
