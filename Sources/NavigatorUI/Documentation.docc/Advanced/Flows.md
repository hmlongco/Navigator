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
    associatedtype Value

    var checkpoint: NavigationFlowCheckpoint<Value>? { get set }

    func start() -> FlowResult<Self>
    func next() async throws -> FlowResult<Self>

    func onComplete()
    func onComplete(_ value: Value)
    func onCancel()
    func onError(_ error: Error)
}
```

`next()` is `async throws` because deciding what comes next may need to await a network call or surface an error. ``FlowResult`` is generic over the flow type, and its terminal cases (`.complete`, `.completeWithValue`, `.cancel`, `.error`) carry the flow itself, so any state the work mutated travels with the result wherever the navigator routes it next. All four lifecycle hooks have empty default implementations. Override only the ones you care about.

```swift
public enum FlowResult<Flow: NavigationFlow> {
    case destination(Flow.Destination)
    case complete(Flow)
    case completeWithValue(Flow.Value, Flow)
    case cancel(Flow)
    case error(Flow, Error)
}
```

The `Value` associated type is unconstrained and has no default. Conforming types declare it explicitly with `typealias Value = SomeType`, or, more commonly, let Swift infer it from the generic argument on the `checkpoint` property. A flow that doesn't return a value typically declares `var checkpoint: NavigationFlowCheckpoint<Void>?` and lets `Value = Void` fall out by inference. A flow that returns a `String` declares `var checkpoint: NavigationFlowCheckpoint<String>?` and gets `Value = String`. No marker types required.

Here's a real flow: an onboarding sequence that collects a name and email, walks through a confirmation screen, and returns the user's first name to whoever started it.

```swift
nonisolated struct OnboardingFlow: NavigationFlow {

    var checkpoint: NavigationFlowCheckpoint<String>?

    var firstName: String = ""
    var lastName: String = ""
    var email: String = ""
    var onboarded: Bool = false

    init(firstName: String = "") {
        self.firstName = firstName
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
        if !onboarded {
            let copy = copy { $0.onboarded = true }
            return .destination(.onboarded(copy))
        }
        return .completeWithValue(firstName, self)
    }

    var isValidEmail: Bool {
        email.range(of: #"^\S+@\S+\.\S+$"#, options: .regularExpression) != nil
    }
}
```

Notice what isn't there. No `@Observable`. No class. No `ObservableObject`. No shared store. No completion closure passed in at construction. The flow is a plain struct. The flow *is* its state, and the value it returns at the end (`firstName`) lives in the same struct as everything else.

Two small details. The `Value` associated type isn't declared explicitly. Swift infers `Value = String` from `checkpoint: NavigationFlowCheckpoint<String>?` because the protocol declares `checkpoint: NavigationFlowCheckpoint<Value>?` and the generic argument resolves the associated type for free. And the inner enum below is named `Destination` (singular) to match the protocol's associatedtype, so the compiler infers `Destination` from the nested type without an explicit `typealias`.

### The Flow Is the State

That's the part worth repeating. The flow struct holds the data the sequence collects, and it travels through the destination enum as an associated value.

```swift
extension OnboardingFlow {
    nonisolated enum Destination: NavigationDestination {
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
    if !onboarded {
        let copy = copy { $0.onboarded = true }
        return .destination(.onboarded(copy))
    }
    return .completeWithValue(firstName, self)
}
```

Each branch reads a piece of state and decides the next move. The first few branches push a destination. The `!onboarded` branch flips a flag on a copy of the flow and pushes the confirmation screen with that updated copy. The final `.completeWithValue` returns the typed value (`firstName`) to whoever's listening at the flow's checkpoint. Past five or six steps this chain of `if`-checks turns into a debugging puzzle and an explicit step enum is the right refactor.

### Async and Logic Work

The previous example's `next()` is synchronous because it doesn't need to await anything. Real flows often do.

`next()` is `async throws` so it can `await` a network call, a persistence write, or any other effect that produces information needed to decide which step comes next. Mutated state forwards along one of two paths. Terminal cases of `FlowResult` carry the flow directly, so `onComplete()`, `onCancel()`, and `onError(_:)` see the final state. Destination cases carry your destination, and by the convention shown earlier in the `Destination` enum, each destination case carries the flow as its associated value, so the next view receives the mutated copy.

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

### Returning Through a Checkpoint

The flow has accumulated state. The user is on the final screen. Where does the data go?

``NavigationCheckpoint`` already solved this. A view registers a typed handler with `.navigationCheckpoint(_:) { value in ... }`, and any code in the navigator tree can call ``Navigator/returnToCheckpoint(_:value:)`` to pop back to it and deliver a value of the matching type. The mechanism is the navigation publisher routing a value by identifier, set when the handler registers, consumed when the value arrives.

The flow's terminal value uses the same plumbing. Same checkpoint type, same publisher, same handler. The flow just plugs in.

Declare a typed checkpoint the way you would for any other return-value use:

```swift
struct FlowCheckpoints: NavigationCheckpoints {
    static var onboarded: NavigationCheckpoint<String> { checkpoint() }
}
```

Start the flow with `returningTo:`, naming the checkpoint as the anchor:

```swift
navigator.start(OnboardingFlow(), returningTo: FlowCheckpoints.onboarded)
```

The compiler enforces the type match. `FlowCheckpoints.onboarded` is `NavigationCheckpoint<String>` because `OnboardingFlow`'s `checkpoint` property is `NavigationFlowCheckpoint<String>?` and Swift inferred `Value = String` from there. The two pieces have to line up or it doesn't compile.

The flow returns its value from inside its state machine:

```swift
if !onboarded {
    let copy = copy { $0.onboarded = true }
    return .destination(.onboarded(copy))
}
return .completeWithValue(firstName, self)
```

When `next()` returns `.completeWithValue`, the navigator does three things in sequence. Pops the navigation stack to the named checkpoint. Sends the value through the publisher the checkpoint already listens on. Fires the flow's `onComplete(_:)` hook with the same value.

On the receiving side, the parent view registered an ordinary checkpoint handler:

```swift
.navigationCheckpoint(FlowCheckpoints.onboarded) { name in
    self.onboardedName = name
}
```

It doesn't know about flows. It registered for a `String` on a named checkpoint, and that's what arrived. The flow's existence is transparent to the receiver. From the receiver's perspective, this is identical to the `returnToCheckpoint(_:value:)` path you've been using all along.

Flows didn't invent a new termination mechanism. They reused the one that already existed.

#### Default anchor

If `start(_:)` is called without `returningTo:`, the navigator stamps an *indexed* anchor instead: a `(navigator id, path index)` pair captured at the moment `start` ran. The flow pops back to the same navigator and index when it terminates. No named checkpoint, no value routing. This is the right default for flows that don't return a value and just need to dismiss back to where they started.

#### Imperative variant

There's an imperative twin to `.completeWithValue` for views that already know they're done:

```swift
Button("Done") {
    navigator.complete(flow, returning: flow.firstName)
}
```

`navigator.complete(_:returning:)` does the same pop, publisher route, and `onComplete(_:)` hook. The state-machine path is usually cleaner because the flow already knows when it's done, but the imperative shortcut is there.

#### One footgun

A typed flow that terminates via plain `.complete(self)` or `navigator.complete(flow)` (without `returning:`) will pop the stack correctly but won't route a value. The handler doesn't fire. Enum cases can't be conditioned on generic parameters, so the compiler won't catch this. When the flow has a real `Value`, always use the value-returning variants.

#### Lifecycle hooks

The hooks have empty default implementations.

```swift
extension NavigationFlow {
    public func onComplete() {}
    public func onComplete(_ value: Value) {}
    public func onCancel() {}
    public func onError(_ error: Error) {}
}
```

Override only the ones you need. `onComplete()` fires for value-less completion (`.complete` / `navigator.complete(flow)`). `onComplete(_:)` fires for typed completion (`.completeWithValue` / `navigator.complete(_:returning:)`). The two are siblings, not stacked.

>Note: All four hooks fire *after* the navigator has returned to the checkpoint, not before. If you override one to show a confirmation toast or kick off a side effect, the user is already back at the entry point, not on the final step of the flow. That's almost always what you want, but worth being explicit about so you don't try to push something onto a stack that no longer exists.

### Cancelling a Flow

A flow can be cancelled two ways, mirroring how it can complete two ways.

The imperative form. A button on a step view calls the navigator directly:

```swift
Button("Cancel") {
    navigator.cancel(flow)
}
```

`navigator.cancel(flow)` pops to the flow's checkpoint and fires `onCancel()`. Clean and direct when a view knows the user just bailed.

The declarative form lives in `next()`. A flow can terminate itself by returning `.cancel(self)` (or `.error(self, e)`) from its state machine. Same outcome, different driver. A flag the view sets before calling `next(_:)` is the usual pattern:

```swift
struct SomeFlow: NavigationFlow {
    var cancelled: Bool = false
    // ... other state

    func next() async throws -> FlowResult<Self> {
        if cancelled { return .cancel(self) }
        // ... normal advancement
    }
}

// In a step view:
Button("Cancel") {
    Task { try? await navigator.next(flow.copy { $0.cancelled = true }) }
}
```

`copy(mutate:)` produces an updated flow with the cancel intent set. `navigator.next(_:)` calls the flow's `next()`, which sees the flag and returns `.cancel(self)`. Same checkpoint pop, same `onCancel()` hook.

Use the imperative form when a view already knows the user cancelled. Use the declarative form when cancellation is a state-driven decision the state machine should make. The same shape works for `.error(self, e)` when an awaited operation fails fatally enough that the flow should tear down rather than let the user retry in place.

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

The view is generic over any flow that satisfies the requirement. Both `CheckoutFlow` and `ProfileEditFlow` route their address step through the same implementation. Each flow still declares its own `Destination` enum and decides which step comes when. Only the screen is shared.

### When Not to Use a Flow

A two-screen interaction that just hands a value back doesn't justify a flow. A named checkpoint with a typed return value is lighter and more direct. See <doc:Checkpoints>.

Reach for a flow when the sequence accumulates state across three or more steps, when the same sequence needs to start from multiple entry points in the app, or when the sequence ends in an effect that needs the accumulated state in one place.

## See Also

- <doc:Checkpoints>
- <doc:Destinations>
- <doc:Dismissible>
