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
///                 .navigationCheckpoint(.home)
///         }
///     }
/// }
/// ```
/// ### Returning
/// As is returning to one.
/// ```swift
/// Button("Cancel") {
///     navigator.returnToCheckpoint(.home)
/// }
/// ```
/// This works even if the checkpoint is in a parent Navigator.
/// ### Defining Checkpoints
/// While checkpoint names can be simple strings, it's usually better to predefine them as shown below.
/// ```swift
/// extension NavigationCheckpoint {
///     public static let home: NavigationCheckpoint = "myApp.home"
///     public static let page2: NavigationCheckpoint = "myApp.page2"
///     public static let settings: NavigationCheckpoint = "myApp.settings"
/// }
/// ```
/// Using the same checkpoint name more than once in the same navigation tree isn't recommended.
public struct NavigationCheckpoint: Codable, Equatable, ExpressibleByStringLiteral, Hashable, Sendable {
    internal let name: String
    internal let index: Int
    public init(stringLiteral value: String) {
        self.name = value
        self.index = 0
    }
    public init(name: String) {
        self.name = name
        self.index = 0
    }
    internal init(name: String, index: Int) {
        self.name = name
        self.index = index
    }
    internal func setting(index: Int) -> NavigationCheckpoint {
        .init(name: name, index: index)
    }
    public static func == (lhs: NavigationCheckpoint, rhs: NavigationCheckpoint) -> Bool {
        lhs.name == rhs.name
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
    @discardableResult
    public func returnToCheckpoint(_ checkpoint: NavigationCheckpoint) -> Bool {
        guard let found = checkpoints[checkpoint.name] else {
            if let parent {
                return parent.returnToCheckpoint(checkpoint)
            } else {
                log("Navigator checkpoint not found: \(checkpoint.name)")
                return false
            }
        }
        log("Navigator returning to checkpoint: \(checkpoint.name)")
        dismissAllChildren()
        pop(to: found.index)
        return true
    }

    /// Allow the code to determine if the checkpoint has been set and is known to the system.
    public nonisolated func canReturnToCheckpoint(_ checkpoint: NavigationCheckpoint) -> Bool {
        guard let found = checkpoints[checkpoint.name] else {
            return parent?.canReturnToCheckpoint(checkpoint) ?? false
        }
        return isPresenting || found.index < path.count
    }

    internal func addCheckpoint(_ checkpoint: NavigationCheckpoint) {
        guard checkpoints[checkpoint.name] == nil else { return }
        log("Navigator adding checkpoint: \(checkpoint.name)")
        checkpoints[checkpoint.name] = checkpoint.setting(index: path.count)
    }

    internal func cleanCheckpoints() {
        checkpoints = checkpoints.filter {
            guard $1.index <= path.count else {
                log("Navigator removing checkpoint: \($1.name)")
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
    public func navigationCheckpoint(_ checkpoint: NavigationCheckpoint) -> some View {
        self.modifier(NavigationCheckpointModifier(checkpoint: checkpoint))
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
    public func navigationReturnToCheckpoint(_ checkpoint: Binding<NavigationCheckpoint?>) -> some View {
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
    public func navigationReturnToCheckpoint(trigger: Binding<Bool>, checkpoint: NavigationCheckpoint) -> some View {
        self.modifier(NavigationReturnToCheckpointTriggerModifier(trigger: trigger, checkpoint: checkpoint))
    }

}

extension Navigator {

    /// Returns to a named checkpoint in the navigation system, passing value to that checkpoint's completion handler.
    ///
    /// This function will pop and/or dismiss intervening views as needed.
    @MainActor
    @discardableResult
    public func returnToCheckpoint<T>(_ checkpoint: NavigationCheckpoint, value: T?) -> Bool {
        guard canReturnToCheckpoint(checkpoint) else {
            return false
        }
        send(CheckpointResult(name: checkpoint.name, value: value))
        return true
    }

}

extension View {

    /// Establishes a navigation checkpoint with a completion handler.
    public func navigationCheckpoint<T: Hashable>(_ checkpoint: NavigationCheckpoint, completion: @escaping (T?) -> Void) -> some View {
        self
            .onNavigationReceive { (result: CheckpointResult<T>) in
                guard result.name == checkpoint.name else {
                    return .cancel
                }
                completion(result.value)
                return .checkpoint(checkpoint)
            }
            .navigationCheckpoint(checkpoint)
    }

}

internal class CheckpointResult<T>: Hashable, CustomStringConvertible {
    internal let name: String
    internal let value: T?
    internal init(name: String, value: T? = nil) {
        self.name = name
        self.value = value
    }
    var description: String {
        if let value {
            "checkpoint value: \(value)"
        } else {
            "checkpoint value: nil"
        }
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
    static func == (lhs: CheckpointResult<T>, rhs: CheckpointResult<T>) -> Bool {
        lhs.name == rhs.name
    }
}

private struct NavigationCheckpointValueModifier<T>: ViewModifier {
    @Environment(\.navigator) var navigator: Navigator
    internal let checkpoint: NavigationCheckpoint
    internal let completion: (T?) -> Void
    func body(content: Content) -> some View {
        content
            .onNavigationReceive { (result: CheckpointResult<T>) in
                guard result.name == checkpoint.name else {
                    return .cancel
                }
                completion(result.value)
                return .checkpoint(checkpoint)
            }
            .navigationCheckpoint(checkpoint)
    }
}

private struct NavigationCheckpointModifier: ViewModifier {
    @Environment(\.navigator) var navigator: Navigator
    internal let checkpoint: NavigationCheckpoint
    func body(content: Content) -> some View {
        content
            .modifier(WrappedModifier(checkpoint: checkpoint, navigator: navigator))
    }
    // Wrapped modifier allows parent environment variables can be extracted and passed to navigator.
    struct WrappedModifier:  ViewModifier {
        init(checkpoint: NavigationCheckpoint, navigator: Navigator) {
            navigator.addCheckpoint(checkpoint)
        }
        func body(content: Content) -> some View {
            content
        }
    }
}

private struct NavigationReturnToCheckpointModifier: ViewModifier {
    @Binding internal var checkpoint: NavigationCheckpoint?
    @Environment(\.navigator) internal var navigator: Navigator
    func body(content: Content) -> some View {
        content
            .onChange(of: checkpoint) { checkpoint in
                if let checkpoint {
                    navigator.returnToCheckpoint(checkpoint)
                    self.checkpoint = nil
                }
            }
    }
}

private struct NavigationReturnToCheckpointTriggerModifier: ViewModifier {
    @Binding internal var trigger: Bool
    internal let checkpoint: NavigationCheckpoint
    @Environment(\.navigator) internal var navigator: Navigator
    func body(content: Content) -> some View {
        content
            .onChange(of: trigger) { trigger in
                if trigger {
                    navigator.returnToCheckpoint(checkpoint)
                    self.trigger = false
                }
            }
    }
}
