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

    func start() -> FlowResult<Destination>
    mutating func next() -> FlowResult<Destination>

    func onComplete()
    func onCancel()
    func onError(_ error: Error)
}
```

The three lifecycle hooks have empty default implementations. Override only the ones you care about.

Here's a real flow: an onboarding sequence that collects a name and email, submits them, and shows a confirmation screen before tearing down.

```swift
nonisolated struct OnboardingFlow: NavigationFlow {
    var checkpoint: NavigationFlowCheckpoint?

    var firstName: String = ""
    var lastName: String = ""
    var email: String = ""

    private let handler: @Sendable (String, String, String) async throws -> Void

    init(handler: @escaping @Sendable (String, String, String) async throws -> Void) {
        self.handler = handler
    }

    func start() -> FlowResult<Destinations> {
        .destination(.welcome(self))
    }

    mutating func next() -> FlowResult<Destinations> {
        if firstName.isEmpty || lastName.isEmpty {
            return .destination(.name(self))
        }
        if email.isEmpty {
            return .destination(.email(self))
        }
        return .destination(.completed(self))
    }

    func submit() async throws {
        try await handler(firstName, lastName, email)
    }
}
```

Notice what isn't there. No `@Observable`. No class. No `ObservableObject`. No shared store. The flow is a plain struct. The flow *is* its state.

### The Flow Is the State

That's the part worth repeating. The flow struct holds the data the sequence collects, and it travels through the destination enum as an associated value.

```swift
extension OnboardingFlow {
    nonisolated enum Destinations: NavigationDestination {
        case welcome(OnboardingFlow)
        case name(OnboardingFlow)
        case email(OnboardingFlow)
        case completed(OnboardingFlow)

        var body: some View {
            switch self {
            case let .welcome(flow):
                WelcomeView(flow)
            case let .name(flow):
                NameView(flow)
            case let .email(flow):
                EmailView(flow)
            case let .completed(flow):
                CompletedView(flow)
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
                navigator.next(flow)
            }
            .disabled(flow.firstName.isEmpty || flow.lastName.isEmpty)
        }
    }
}
```

There's no view model. There's no shared store. The `TextField` binds straight into the flow's stored properties via `@State`'s projected binding, and the button hands the mutated copy back to the navigator. That's the entire data layer for this screen.

Value semantics are doing real work here. Each pushed step gets its own copy of the flow as it existed at push time, so navigating back doesn't observe later mutations, and SwiftUI's diff over the navigation path behaves exactly the way it does for any other `Hashable` value. The flow is just data in the path.

### Driving the Sequence

Two methods on ``Navigator`` move a flow forward.

`navigator.start(flow)` stamps a checkpoint capturing the current navigator and its path index, then calls the flow's `start()` and routes the result. `navigator.next(flow)` calls `next()` and routes the result.

```swift
Button("Start Onboarding Flow") {
    navigator.start(OnboardingFlow { firstName, lastName, email in
        try await Task.sleep(for: .seconds(1))
        print("Onboarded \(firstName) \(lastName) <\(email)>")
    })
}
```

Both methods route the returned ``FlowResult`` the same way. A `.destination(d)` pushes the next step. A `.complete`, `.cancel`, or `.error(e)` returns the stack to the checkpoint and fires the corresponding hook.

The flow's `next()` is the state machine. It inspects the current fields and decides what comes next or that you're done.

```swift
mutating func next() -> FlowResult<Destinations> {
    if firstName.isEmpty || lastName.isEmpty {
        return .destination(.name(self))
    }
    if email.isEmpty {
        return .destination(.email(self))
    }
    return .destination(.completed(self))
}
```

Each branch reads a piece of state and decides what comes next. Notice that `next()` never returns `.complete` here. The flow's last screen always pushes a confirmation view, and terminating the flow is the confirmation view's job, not the state machine's. Past five or six steps this chain of `if`-checks turns into a debugging puzzle and an explicit step enum is the right refactor.

### Carrying Dependencies Into the Flow

The flow needs to do *something* with the data it collects. In the example above, the initializer takes an async closure and stores it privately.

```swift
private let handler: @Sendable (String, String, String) async throws -> Void
```

That's how the flow gets the thing it eventually needs to call without coupling its definition to a specific submission service. The closure is `let`, set once at construction, called from the flow's own `submit()` method.

Keep the handler private. Views inside the flow have no reason to know how submission works, only that they can ask the flow to perform it. The flow exposes a method:

```swift
func submit() async throws {
    try await handler(firstName, lastName, email)
}
```

The method is non-mutating on purpose. A `mutating async` method can't be called against actor-isolated `@State` storage in Swift 6 — the compiler refuses to hand the storage out as `inout` across the suspension. Keeping `submit()` non-mutating sidesteps the problem and matches the natural call site `try await flow.submit()`.

There's also a small price on conformance. Closures are not `Hashable`, so the moment you add one, the auto-synthesized `Hashable` conformance disappears. Implement it manually over the value properties and ignore the closure.

```swift
static func == (lhs: OnboardingFlow, rhs: OnboardingFlow) -> Bool {
    lhs.checkpoint == rhs.checkpoint
        && lhs.firstName == rhs.firstName
        && lhs.lastName == rhs.lastName
        && lhs.email == rhs.email
}

func hash(into hasher: inout Hasher) {
    hasher.combine(checkpoint)
    hasher.combine(firstName)
    hasher.combine(lastName)
    hasher.combine(email)
}
```

This is safe because the closure is fixed for the lifetime of the flow. Excluding it from equality cannot make two genuinely-different flows compare equal in any way navigation cares about.

### Async Work in a Flow

The flow protocol is synchronous on purpose. `start()` and `next()` are decisions, not effects. Anything that needs to await belongs in the view layer, which calls `navigator.next(flow)` once the await resolves.

```swift
struct EmailView: View {
    @Environment(\.navigator) private var navigator
    @State var flow: OnboardingFlow
    @State var submitting: Bool = false
    @State var errorMessage: String?

    var body: some View {
        Form {
            Section("Your Email") {
                TextField("name@example.com", text: $flow.email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
            }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
            Button(submitting ? "Submitting..." : "Submit") {
                Task { await submit() }
            }
            .disabled(submitting || !isValidEmail(flow.email))
        }
    }

    func submit() async {
        submitting = true
        defer { submitting = false }
        errorMessage = nil
        do {
            try await flow.submit()
            navigator.next(flow)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

Notice what the view doesn't know. It doesn't know the flow holds a closure. It doesn't know what `submit()` does internally. It asks the flow to submit, and on success hands the same flow back to the navigator. The flow's internals stay the flow's business.

On failure the view stays put and surfaces the error. On success, `navigator.next(flow)` pushes the confirmation screen. The confirmation screen terminates the flow explicitly, which is the next section.

>Note: If an awaited failure should kill the flow entirely rather than let the user retry in place, call `navigator.error(flow, error:)` instead of `navigator.next(flow)`. The flow's `onError(_:)` hook fires after the stack has already returned to the checkpoint, so use it for telemetry or for surfacing a toast at the entry point, not for recovery inside the flow.

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
struct CompletedView: View {
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

### Class Flows

The example above is a plain struct. For most sequences that's all you need. Three or four fields, value semantics throughout, the navigator copies the flow from step to step and nobody else has to think about it.

That stops being a good fit when the flow holds state that's expensive to copy or state that has to be shared with code outside the flow. A checkout sequence accumulating cart line items, a shipping address, a payment method, promo codes, and tax calculations is a lot of bytes to hand around every time the user taps Next. It probably also needs to coordinate with a global cart that's already a reference type. 

In which case we simply make the flow a class.

```swift
@MainActor
final class CheckoutFlow: NavigationFlow {
    var checkpoint: NavigationFlowCheckpoint?

    let cart: Cart
    var shipping: Address?
    var payment: PaymentMethod?

    init(cart: Cart) {
        self.cart = cart
    }

    func start() -> FlowResult<Destinations> { .destination(.review(self)) }
    func next() -> FlowResult<Destinations> { /* inspect state, return next step */ }

    static func == (lhs: CheckoutFlow, rhs: CheckoutFlow) -> Bool { lhs === rhs }
    func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
}
```

`Hashable` is by identity now, which is the right semantic for a class. Two instances are the same flow only if they're literally the same object. `next()` is no longer `mutating` either, because the class itself is the mutable storage.

## Protocol Flows

We can go further. ``NavigationFlow`` is a protocol, so flows themselves can be protocols. That's how you reuse a screen across different sequences. An "address entry" view that belongs in both checkout and profile editing doesn't want to be hard-coded to one concrete flow type.

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
