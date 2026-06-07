# Navigation Flows

Managing state across a sequence of related views.

## Overview

Onboarding wizards, multi-step forms, guided checkout. They all share two awkward facts: each step needs to see what previous steps collected, and "done" means tearing down every screen the sequence pushed.

Solving that with raw `NavigationLink` and a chain of `@Binding` hand-offs forces the state to live somewhere uncomfortable. Usually that's in a parent view or a view model that outlives the sequence and has no business knowing about it. Drop in an `ObservableObject` and you've added a shared mutable container to the environment for a workflow that only existed for thirty seconds.

``NavigationFlow`` collapses both problems into one type. A struct that owns the data the sequence collects, and also which also uses that knowledge to determine which step comes next.

This makes the flow state dependent.

Just like SwiftUI wants.

### Defining a Flow

The protocol is small. An associated `Destination: NavigationDestination`, a checkpoint property that Navigator manages for you, and two methods that drive the sequence forward.

```swift
@MainActor
public protocol NavigationFlow: Hashable {

    associatedtype Destination: NavigationDestination

    var checkpoint: NavigationFlowCheckpoint? { get set }

    func start() -> FlowResult<Self>
    func next() async throws -> FlowResult<Self>

    func onComplete()
    func onCancel()
    func onError(_ error: Error)
}
```

`next()` is `async throws` because deciding what comes next may need to await a network call or surface an error. ``FlowResult`` is generic over the flow type, and its terminal cases (`.complete`, `.cancel`, `.error`) carry the flow itself, so any state the work mutated travels with the result wherever the navigator routes it next. The three lifecycle hooks have empty default implementations. Override only the ones you care about.

```swift
public enum FlowResult<Flow: NavigationFlow> {
    case destination(Flow.Destination)
    case complete(Flow)
    case cancel(Flow)
    case error(Flow, Error)
}
```

Here's a real flow: an onboarding sequence that collects a name and email and fires a completion callback when the user finishes.

```swift
nonisolated struct OnboardingFlow: NavigationFlow {
    typealias Destination = Destinations

    var checkpoint: NavigationFlowCheckpoint?

    var firstName: String = ""
    var lastName: String = ""
    var email: String = ""

    private let completion: Callback<(String, String, String)>

    init(completion: @escaping @Sendable (String, String, String) -> Void) {
        self.completion = .init(handler: completion)
    }

    func start() -> FlowResult<Self> {
        .destination(.welcome(self))
    }

    func next() async throws -> FlowResult<Self> {
        if firstName.isEmpty || lastName.isEmpty {
            return .destination(.name(self))
        }
        if !isValidEmail {
            return .destination(.email(self))
        }
        return .destination(.onboarded(self))
    }

    var isValidEmail: Bool {
        email.range(of: #"^\S+@\S+\.\S+$"#, options: .regularExpression) != nil
    }

    func onComplete() {
        completion((firstName, lastName, email))
    }
}
```

Notice what isn't there. No `@Observable`. No class. No `ObservableObject`. No shared store. The flow is a plain struct. The flow *is* its state.

The explicit `typealias Destination = Destinations` is required. Because `start()` and `next()` both return `FlowResult<Self>`, neither signature mentions `Destination` directly, so the compiler has no way to infer the associatedtype from method shape alone. Declare it.

### The Flow Is the State

That's the part worth repeating. The flow struct holds the data the sequence collects, and it travels through the destination enum as an associated value.

```swift
extension OnboardingFlow {
    nonisolated enum Destinations: NavigationDestination {
        case welcome(OnboardingFlow)
        case name(OnboardingFlow)
        case email(OnboardingFlow)
        case onboarded(OnboardingFlow)

        var body: some View {
            switch self {
            case let .welcome(flow):
                WelcomeView(flow)
            case let .name(flow):
                NameView(flow)
            case let .email(flow):
                EmailView(flow)
            case let .onboarded(flow):
                OnboardedView(flow)
            }
        }
    }
}
```

Each step receives the current flow, mutates its own fields, and hands the updated copy back to the navigator.

```swift
struct NameView: View {
    @Environment(\.navigator) private var navigator
    @State var flow: OnboardingFlow

    var body: some View {
        Form {
            Section("Your Name") {
                TextField("First name", text: $flow.firstName)
                TextField("Last name", text: $flow.lastName)
            }
            Button("Next") {
                Task { try? await navigator.next(flow) }
            }
            .disabled(flow.firstName.isEmpty || flow.lastName.isEmpty)
        }
    }
}
```

`navigator.next(_:)` is `async throws`, so the button wraps it in a `Task` and either handles or swallows any error the flow raises.

There's no view model. There's no shared store. The `TextField` binds straight into the flow's stored properties via `@State`'s projected binding, and the button hands the mutated copy back to the navigator. That's the entire data layer for this screen.

Value semantics are doing real work here. Each pushed step gets its own copy of the flow as it existed at push time, so navigating back doesn't observe later mutations, and SwiftUI's diff over the navigation path behaves exactly the way it does for any other `Hashable` value. The flow is just data in the path.

### Driving the Sequence

Two methods on ``Navigator`` move a flow forward.

`navigator.start(flow)` stamps a checkpoint capturing the current navigator and its path index, then calls the flow's `start()` and routes the result. `navigator.next(flow)` calls `next()` and routes the result.

```swift
Button("Start Onboarding Flow") {
    navigator.start(OnboardingFlow { firstName, lastName, email in
        print("Onboarded \(firstName) \(lastName) with <\(email)>")
    })
}
```

`navigator.start(_:)` is synchronous because `start()` on the protocol is synchronous. `navigator.next(_:)` is `async throws` because `next()` is, so callers wrap it in a `Task`. Both route the returned ``FlowResult`` the same way: `.destination(d)` pushes the next step, and `.complete`, `.cancel`, or `.error(e)` returns the stack to the checkpoint and fires the corresponding hook.

The flow's `next()` is the state machine. It inspects the current fields, optionally does asynchronous work, and returns a `FlowResult<Self>` describing where the navigator should go.

```swift
func next() async throws -> FlowResult<Self> {
    if firstName.isEmpty || lastName.isEmpty {
        return .destination(.name(self))
    }
    if !isValidEmail {
        return .destination(.email(self))
    }
    return .destination(.onboarded(self))
}
```

Each branch reads a piece of state and returns the next destination. Notice that `next()` never returns `.complete` here. The flow's last screen always pushes a confirmation view, and terminating the flow is the confirmation view's job, not the state machine's. Past five or six steps this chain of `if`-checks turns into a debugging puzzle and an explicit step enum is the right refactor.

### Hiding the Handler

The flow needs to do *something* with the data it collects. The naive answer is to hand the handler into the final view as a parameter and let the view call it.

Don't do that.

The completion screen has no business knowing that a callback exists. It wants to know how to dismiss the flow when the user taps Done. The callback, the arguments, the data the callback needs, none of that is the view's problem.

So the closure goes on the flow, private. And the flow fires it from one of the lifecycle hooks the protocol already gives you.

```swift
private let completion: Callback<(String, String, String)>

func onComplete() {
    completion((firstName, lastName, email))
}
```

`onComplete()` is exactly what it sounds like. A hook that fires after the flow completes. The view calls `navigator.complete(flow)`, the navigator restores the stack to the checkpoint, then calls the flow's `onComplete()`, which fires the closure with the data the flow has been accumulating.

This is the division the protocol is designed around. `start()` and `next()` are navigation decisions. The hooks are where side effects go. Don't reach for the view layer to invoke a callback the flow already has all the information to invoke itself.

#### Why `Callback`, not a bare closure?

``NavigationFlow`` requires `Hashable` so the flow can ride the navigation path as part of a destination enum's associated value. The moment you store a raw closure on the flow you lose the auto-synthesized `Hashable` conformance, because closures aren't `Hashable`.

You could implement `Hashable` by hand, list every value property in `==` and `hash(into:)`, and skip the closure. That works. But Navigator ships ``Callback`` for exactly this case.

```swift
public struct Callback<Value>: Hashable, Equatable {
    public let identifier: String
    public let handler: (Value) -> Void
    // ... hashes on identifier, calls handler via callAsFunction
}
```

`Callback<Value>` wraps a closure with a stable identifier (a fresh UUID by default, or one you pass in). Equality and hashing operate on the identifier instead of the closure itself, so the wrapping flow keeps its synthesized `Hashable` conformance with no boilerplate. The trade is that two callbacks created with the same closure compare unequal, which is the right semantic when the closure is constructed once at flow init and never replaced.

Wrap the incoming closure in the flow's initializer:

```swift
init(completion: @escaping @Sendable (String, String, String) -> Void) {
    self.completion = .init(handler: completion)
}
```

And invoke it via `callAsFunction`, which lets you call the wrapper like a closure:

```swift
func onComplete() {
    completion((firstName, lastName, email))
}
```

The single tuple argument matches Callback's `Value` type parameter.

>Warning: `Callback` is not `Codable`. Storing one on a flow disables state restoration for any `ManagedNavigationStack` that hosts the flow, and it can interfere with deep linking because external URL handlers can't synthesize the underlying closure. When state restoration or deep-link reachability matters more than a one-shot callback, return the collected value through a checkpoint instead. See <doc:Checkpoints>.

### Async and Logic Work

The previous example's `next()` is synchronous because it doesn't need to await anything. Real flows often do.

`next()` is `async throws` so it can `await` a network call, a persistence write, or any other effect that produces information needed to decide which step comes next. Mutated state forwards along one of two paths. Terminal cases of `FlowResult` carry the flow directly, so `onComplete()`, `onCancel()`, and `onError(_:)` see the final state. Destination cases carry your destination, and by the convention shown earlier in the `Destinations` enum, each destination case carries the flow as its associated value, so the next view receives the mutated copy.

```swift
func next() async throws -> FlowResult<Self> {
    if firstName.isEmpty || lastName.isEmpty {
        return .destination(.name(self))
    }
    if !isValidEmail {
        return .destination(.email(self))
    }
    if !isRegistered {
        let (userID, termsRequired) = try await api.register(email: email, name: firstName)
        let updated = copy {
            $0.userID = userID
            $0.isTermsRequired = termsRequired
            $0.isRegistered = true
        }
        if termsRequired {
            return .destination(.terms(updated))
        }
        return .destination(.onboarded(updated))
    }
    return .destination(.onboarded(self))
}
```

A few things to note here.

`copy(mutate:)` is a default-implemented helper on ``NavigationFlow`` that takes a closure, applies it to a mutable copy of `self`, and returns the result. It exists specifically so that producing updated state from a non-mutating method stays a one-liner. The returned `updated` is the value that rides into `.destination(.terms(updated))` or `.destination(.onboarded(updated))`, and that's how `TermsView` or `OnboardedView` ends up holding a flow with `userID` set.

If the async work throws, the error propagates out through `navigator.next(flow)`. The view's `try?` swallows it. If you'd rather treat a failure as fatal to the flow, return `.error(updated, e)` from `next()` instead. The navigator routes that to `onError(_:)` after restoring the stack to the checkpoint, and the flow it receives is the one you handed back, so any mutated state is still observable.

Next, the api call returns whether or not the user should see the terms of agreement view. Perhaps it's location dependent. But regardless of how it's determined on the back end, the flow is able to decide the next view to be shown.

>Note: The async work happens before any navigation occurs. The user sees the last screen they were on until `next()` returns. If the work might take a moment, the calling view should reflect that, usually by disabling its action button or showing a progress indicator while its `Task` is in flight.

### Mixing Navigation Methods

A flow can mix presentation methods across its steps. The first step opens as a sheet, the rest push within it.

```swift
var method: NavigationMethod {
    switch self {
    case .welcome:
        .managedSheet
    default:
        .push
    }
}
```

The checkpoint is recorded relative to the navigator that called `start()`, so completion dismisses the sheet *and* pops back to whatever pushed the start button. One mechanism, no manual coordination between push depth and sheet presentation.

See <doc:Dismissible> for the full picture of how Navigator tears down nested presentations.

### Completion, Cancellation, and Errors

A flow ends one of two ways. Either `next()` returns one of the terminal `FlowResult` cases (`.complete`, `.cancel`, `.error`), or a view calls the equivalent method on the navigator directly (`navigator.complete(flow)`, `navigator.cancel(flow)`, `navigator.error(flow, error:)`). Both routes do the same thing: restore the navigation stack to the checkpoint, then call the matching hook on the flow.

The onboarding example uses the imperative form. The confirmation screen knows it's the last step, so it doesn't need the state machine to figure that out.

```swift
struct OnboardedView: View {
    @Environment(\.navigator) private var navigator
    @State var flow: OnboardingFlow

    var body: some View {
        VStack {
            Text("Completed!").font(.largeTitle)
            Text("That's all there is to it!")
            Button("Done") {
                navigator.complete(flow)
            }
        }
        .navigationBarBackButtonHidden()
    }
}
```

The hooks themselves have empty default implementations.

```swift
extension NavigationFlow {
    public func onComplete() {}
    public func onCancel() {}
    public func onError(_ error: Error) {}
}
```

Override only what you need. A welcome toast in `onComplete()`. Telemetry in `onCancel()`. Crash reporting in `onError(_:)`.

>Note: The hooks fire *after* the navigator has returned to the checkpoint, not before. If `onComplete()` wants to show a confirmation, the user is already back at the entry point, not on the final step of the flow. That's almost always what you want, but it's worth being explicit about so you don't try to push something onto a stack that no longer exists.

## Protocol Flows

We can go further. ``NavigationFlow`` is a protocol, but flows themselves can *also* be protocols. 

Why? What if we wanted to reuse a screen across different sequences. An "address entry" view that belongs in both checkout and profile editing doesn't want to be hard-coded to one concrete flow type.

```swift
protocol AddressCollecting: NavigationFlow {
    var shipping: Address? { get set }
}

extension CheckoutFlow: AddressCollecting {}
extension ProfileEditFlow: AddressCollecting {}

struct AddressEntryView<Flow: AddressCollecting>: View {
    @State var flow: Flow
    // body binds against $flow.shipping
}
```

The view is generic over any flow that satisfies the requirement. Both `CheckoutFlow` and `ProfileEditFlow` route their address step through the same implementation. Each flow still declares its own `Destinations` enum and decides which step comes when. Only the screen is shared.

### When Not to Use a Flow

A two-screen interaction that just hands a value back doesn't justify a flow. A named checkpoint with a typed return value is lighter and more direct. See <doc:Checkpoints>.

Reach for a flow when the sequence accumulates state across three or more steps, when the same sequence needs to start from multiple entry points in the app, or when the sequence ends in an effect that needs the accumulated state in one place.

## See Also

- <doc:Checkpoints>
- <doc:Destinations>
- <doc:Dismissible>
