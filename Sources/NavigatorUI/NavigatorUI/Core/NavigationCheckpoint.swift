//
//  NavigationCheckpoint.swift
//  Navigator
//
//  Created by Michael Long on 11/20/24.
//

import SwiftUI

/// NavigationCheckpoints provide named checkpoints in the navigation tree.
///
/// Navigators know how to pop and/or dismiss views in order to return a previously defined checkpoint.
/// ### Setting Checkpoints
/// Setting a checkpoint is easy.
/// ```swift
/// struct RootHomeView: View {
///     var body: some View {
///         ManagedNavigationStack {
///             HomeContentView(title: "Home Navigation")
///                 .navigationDestination(HomeDestinations.self)
///                 .navigationCheckpoint(KnowCheckpoints.home)
///         }
///     }
/// }
/// ```
/// ### Returning
/// As is returning to one.
/// ```swift
/// Button("Cancel") {
///     navigator.returnToCheckpoint(KnowCheckpoints.home)
/// }
/// ```
/// This works even if the checkpoint is in a parent Navigator.
/// ### Defining Checkpoints
/// Define your checkpoints as shown below, conforming your definitions to `NavigationCheckpoints` and specifying the return type
/// of the checkpoint (or void if none).
/// ```swift
/// struct KnowCheckpoints: NavigationCheckpoints {
///     public static var home: NavigationCheckpoint<Void> { checkpoint() }
///     public static var page2: NavigationCheckpoint<Void> { checkpoint() }
///     public static var settings: NavigationCheckpoint<Int> { checkpoint() }
/// }
/// ```
/// Checkpoints are lightweight structs. Return a new instance when needed.
///
/// Defining with `{ checkpoint() }` ensures a unique name for each variable instance.
nonisolated public struct NavigationCheckpoint<T>: Equatable, Hashable, Sendable {

    /// The unique name for this checkpoint, including its value type.
    ///
    /// Names are used internally to index and resolve checkpoints when
    /// returning to them later.
    public let name: String

    internal let identifier: String?

    public init(name: String) {
        self.name = "\(name).\(T.self)"
        self.identifier = nil
    }

    private init(name: String, identifier: String? = nil) {
        self.name = name
        self.identifier = identifier
    }

    internal func setting(index: Int) -> AnyNavigationCheckpoint {
        AnyNavigationCheckpoint(name: name, identifier: identifier, index: index)
    }

    internal func setting(identifier: String?) -> NavigationCheckpoint {
        NavigationCheckpoint(name: name, identifier: identifier)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        if let identifier {
            hasher.combine(identifier)
        }
    }

    public static func == (lhs: NavigationCheckpoint, rhs: NavigationCheckpoint) -> Bool {
        lhs.name == rhs.name && lhs.identifier == rhs.identifier
    }

}

/// A marker protocol for types that define reusable navigation checkpoints.
///
/// Types conforming to this protocol are expected to expose static
/// ``NavigationCheckpoint`` properties, typically via the helper
/// ``NavigationCheckpoints/checkpoint(_:)``.
public protocol NavigationCheckpoints {}

extension NavigationCheckpoints {

    /// Creates a new checkpoint for the conforming type.
    ///
    /// This helper is usually called from a computed static property to
    /// ensure each checkpoint gets a unique name:
    ///
    /// ```swift
    /// struct KnownCheckpoints: NavigationCheckpoints {
    ///     static var home: NavigationCheckpoint<Void> { checkpoint() }
    /// }
    /// ```
    ///
    /// - Parameter name: An optional name to incorporate into the checkpoint,
    ///   defaulting to the calling property name.
    /// - Returns: A new checkpoint value for the specified type.
    public static func checkpoint<T>(_ name: String = #function) -> NavigationCheckpoint<T> {
        assert("\(Self.self)" != name, "Call within computed property. e.g. '{ checkpoint() }` and not `= checkpoint()'.")
        return NavigationCheckpoint<T>(name: "\(Self.self).\(name)")
    }
}

extension Navigator {

    /// Returns to a named checkpoint in the navigation system.
    ///
    /// This function will pop and/or dismiss intervening views as needed.
    /// ```swift
    /// Button("Cancel") {
    ///     navigator.returnToCheckpoint(.home)
    /// }
    /// ```
    @MainActor
    public func returnToCheckpoint<T>(_ checkpoint: NavigationCheckpoint<T>) {
        guard let (navigator, found) = find(checkpoint) else {
            log(.warning("checkpoint not found in current navigation tree: \(checkpoint.name)"))
            return
        }
        log(.checkpoint(.returning(checkpoint.name)))
        navigator.returnToIndex(found.index)
        // send trigger to specific action handler
        if let identifier = found.identifier {
            let values = NavigationSendValues(navigator: self, identifier: identifier, value: CheckpointAction())
            publisher.send(values)
        }
    }

    /// Returns to a named checkpoint in the navigation system, passing value to that checkpoint's completion handler.
    ///
    /// This function will pop and/or dismiss intervening views as needed.
    /// ```swift
    /// Button("Cancel") {
    ///     navigator.returnToCheckpoint(.transaction, value: account)
    /// }
    /// ```
    @MainActor
    public func returnToCheckpoint<T: Hashable>(_ checkpoint: NavigationCheckpoint<T>, value: T) {
        guard let (navigator, found) = find(checkpoint) else {
            log(.warning("checkpoint value handler not found: \(checkpoint.name)"))
            return
        }
        log(.checkpoint(.returningWithValue(checkpoint.name, value)))
        navigator.returnToIndex(found.index)
        // send value to specific receive handler
        if let identifier = found.identifier {
            let values = NavigationSendValues(navigator: self, identifier: identifier, value: value)
            publisher.send(values)
        }
    }

    /// Allows the code to determine if the checkpoint has been set and is known to the system.
    public func canReturnToCheckpoint<T>(_ checkpoint: NavigationCheckpoint<T>) -> Bool {
        find(checkpoint) != nil
    }

    @MainActor
    internal func addCheckpoint<T>(_ checkpoint: NavigationCheckpoint<T>) {
        let entry = checkpoint.setting(index: path.count)
        if let found = checkpoints[entry.key] {
            if checkpoint.identifier != found.identifier {
                checkpoints[entry.key] = entry.setting(identifier: checkpoint.identifier)
            }
            return
        }
        checkpoints[entry.key] = entry
        log(.checkpoint(.adding(checkpoint.name)))
    }

    @MainActor
    internal func returnToIndex(_ index: Int) {
        _ = dismissAnyChildren()
        _ = pop(to: index)
    }

    internal func find<T>(_ checkpoint: NavigationCheckpoint<T>) -> (Navigator, AnyNavigationCheckpoint)? {
        findNamed(checkpoint.name)
    }

    /// Looks up a registered checkpoint by its stable name.
    ///
    /// Same search semantics as `find<T>(_:)` but reachable without a typed
    /// `NavigationCheckpoint<T>` value — used by flows that store only the
    /// checkpoint's name on their anchor.
    internal func findNamed(_ name: String) -> (Navigator, AnyNavigationCheckpoint)? {
        if let found = checkpoints.values
            .filter({ $0.name == name && (isPresenting || $0.index < path.count) })
            .sorted(by: { $0.index > $1.index })
            .first {
            return (self, found)
        }
        return parent?.findNamed(name)
    }

    internal func cleanCheckpoints() {
        checkpoints = checkpoints.filter {
            guard $1.index <= path.count else {
                log(.checkpoint(.removing($1.key)))
                return false
            }
            return true
        }
    }

}

extension View {

    /// Establishes a named checkpoint in the navigation system.
    ///
    /// Navigators know how to pop and/or dismiss views in order to return to this checkpoint when needed.
    /// ```swift
    /// struct RootHomeView: View {
    ///     var body: some View {
    ///         ManagedNavigationStack {
    ///             HomeContentView(title: "Home Navigation")
    ///                 .navigationDestination(HomeDestinations.self)
    ///                 .navigationCheckpoint(.home)
    ///         }
    ///     }
    /// }
    /// ```
    /// Here, returning to the checkpoint named `.home` will return to the root view in this navigation stack.
    public func navigationCheckpoint<T>(_ checkpoint: NavigationCheckpoint<T>) -> some View {
        self.modifier(NavigationCheckpointModifier(checkpoint: checkpoint))
    }

    /// Establishes a navigation checkpoint with an action handler fired on return.
    public func navigationCheckpoint<T>(_ checkpoint: NavigationCheckpoint<T>, action: @escaping () -> Void) -> some View {
        self.modifier(NavigationCheckpointActionModifier(checkpoint: checkpoint, action: action))
    }

    /// Establishes a navigation checkpoint with a completion handler that accepts a return value.
    public func navigationCheckpoint<T: Hashable>(_ checkpoint: NavigationCheckpoint<T>, completion: @escaping (T) -> Void) -> some View {
        self.modifier(NavigationCheckpointValueModifier(checkpoint: checkpoint, completion: completion))
    }

    /// Declarative `returnToCheckpoint` modifier.
    ///
    /// Just set the checkpoint value to which you want to return.
    /// ```swift
    /// Button("Return To Home") {
    ///     checkpoint = .home
    /// }
    /// .navigationReturnToCheckpoint(trigger: $checkpoint)
    /// ```
    /// Note that executing the checkpoint action will reset the bound value back to nil when complete.
    public func navigationReturnToCheckpoint<T: Hashable>(_ checkpoint: Binding<NavigationCheckpoint<T>?>) -> some View {
        self.modifier(NavigationReturnToCheckpointModifier(checkpoint: checkpoint))
    }

    /// Declarative `returnToCheckpoint` modifier fired by a trigger.
    ///
    /// Just set the checkpoint value to which you want to return.
    /// ```swift
    /// Button("Return To Home") {
    ///     triggerReturn.toggle()
    /// }
    /// .navigationReturnToCheckpoint(trigger: $triggerReturn, checkpoint: .home)
    /// ```
    /// Note that executing the checkpoint action will reset the trigger value back to false when complete.
    public func navigationReturnToCheckpoint<T>(trigger: Binding<Bool>, checkpoint: NavigationCheckpoint<T>) -> some View {
        self.modifier(NavigationReturnToCheckpointTriggerModifier(trigger: trigger, checkpoint: checkpoint))
    }

}

private struct NavigationCheckpointModifier<T>: ViewModifier {
    @Environment(\.navigator) var navigator: Navigator
    internal let checkpoint: NavigationCheckpoint<T>
    func body(content: Content) -> some View {
        content
            .task(id: checkpoint.name) { navigator.addCheckpoint(checkpoint) }
    }
}

private struct CheckpointAction: Hashable {}

private struct NavigationCheckpointActionModifier<T>: ViewModifier {
    @State internal var checkpoint: NavigationCheckpoint<T>
    internal let action: () -> Void
    @Environment(\.navigator) private var navigator: Navigator
    init(
        checkpoint: NavigationCheckpoint<T>,
        action: @escaping () -> Void
    ) {
        self.checkpoint = checkpoint
            .setting(identifier: checkpoint.identifier ?? UUID().uuidString)
        self.action = action
    }
    func body(content: Content) -> some View {
        content
            .onReceive(navigator.publisher) { values in
                if let _: CheckpointAction = values.consume(checkpoint.identifier) {
                    navigator.log(.checkpoint(.returning(checkpoint.name)))
                    action()
                    values.resume(.auto)
                }
            }
            .navigationCheckpoint(checkpoint)
    }
}

private struct NavigationCheckpointValueModifier<T: Hashable>: ViewModifier {
    @State internal var checkpoint: NavigationCheckpoint<T>
    internal let completion: (T) -> Void
    @Environment(\.navigator) private var navigator: Navigator
    init(
        checkpoint: NavigationCheckpoint<T>,
        completion: @escaping (T) -> Void
    ) {
        self.checkpoint = checkpoint.setting(identifier: checkpoint.identifier ?? UUID().uuidString)
        self.completion = completion
    }
    func body(content: Content) -> some View {
        content
            .onReceive(navigator.publisher) { values in
                if let value: T = values.consume(checkpoint.identifier) {
                    navigator.log(.checkpoint(.returningWithValue(checkpoint.name, value)))
                    completion(value)
                    values.resume(.auto)
                }
            }
            .navigationCheckpoint(checkpoint)
    }
}

private struct NavigationReturnToCheckpointModifier<T: Hashable>: ViewModifier {
    @Binding internal var checkpoint: NavigationCheckpoint<T>?
    @Environment(\.navigator) internal var navigator: Navigator
    func body(content: Content) -> some View {
        content
            .onChange(of: checkpoint) { _, checkpoint in
                if let checkpoint {
                    navigator.returnToCheckpoint(checkpoint)
                    self.checkpoint = nil
                }
            }
    }
}

private struct NavigationReturnToCheckpointTriggerModifier<T>: ViewModifier {
    @Binding internal var trigger: Bool
    internal let checkpoint: NavigationCheckpoint<T>
    @Environment(\.navigator) internal var navigator: Navigator
    func body(content: Content) -> some View {
        content
            .onChange(of: trigger) { _, trigger in
                if trigger {
                    navigator.returnToCheckpoint(checkpoint)
                    self.trigger = false
                }
            }
    }
}

internal struct AnyNavigationCheckpoint: Hashable, Sendable {

    let name: String
    var identifier: String?
    var index: Int

    internal init(name: String, identifier: String?, index: Int) {
        self.name = name
        self.identifier = identifier
        self.index = index
    }

    internal var key: String {
        "\(name).\(index)"
    }

    internal func setting(identifier: String?) -> AnyNavigationCheckpoint {
        AnyNavigationCheckpoint(name: name, identifier: identifier, index: index)
    }

    internal func setting(index: Int) -> AnyNavigationCheckpoint {
        guard self.index == 0 else {
            return self
        }
        return AnyNavigationCheckpoint(name: name, identifier: identifier, index: index)
    }

}

extension AnyNavigationCheckpoint: Codable {

    // Coding keys for encoding and decoding
    private enum CodingKeys: String, CodingKey {
        case name
        case index
    }

    // Custom encoder
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(index, forKey: .index)
    }

    // Custom decoder
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.identifier = nil
        self.index = try container.decode(Int.self, forKey: .index)
    }

}
