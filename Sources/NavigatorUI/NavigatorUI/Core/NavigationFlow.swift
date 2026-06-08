//
//  NavigationFlow.swift
//  NavigatorUI
//
//  Created by Michael Long on 10/25/25.
//

import SwiftUI

/// A stateful, resumable sequence of navigation steps driven by a `Navigator`.
///
/// Conforming types model a flow that can emit destinations, complete,
/// cancel, or fail with an error over time. The `Navigator` uses
/// `start()` and `next()` to advance the flow and reacts to each emitted
/// ``FlowResult``.
///
/// Typical usages include onboarding wizards, multi-step forms, or guided
/// flows that may return to a checkpoint when they finish or are cancelled.
@MainActor
public protocol NavigationFlow: Hashable {

    /// The navigation destination types managed by this flow.
    associatedtype Destination: NavigationDestination

    /// The type of value the flow can return to a named checkpoint on completion.
    ///
    /// Unconstrained and has no default. Conforming types either declare
    /// `typealias Value = SomeType`, or let Swift infer it from the generic
    /// argument on the ``checkpoint`` property. Use `Void` for flows that
    /// don't produce a return value.
    associatedtype Value

    /// Checkpoint used by the `Navigator` to restore the navigation
    /// stack to the flow's starting point when it completes, is cancelled,
    /// or should it encounter an error.
    var checkpoint: NavigationFlowCheckpoint<Value>? { get set }

    /// Starts the flow and returns the first navigation result.
    ///
    /// Use this to emit the initial destination or signal that the flow
    /// is already complete, cancelled, or in error.
    func start() -> FlowResult<Self>

    /// Advances the flow to its next step and returns the result.
    ///
    /// This is typically called *after* the user has interacted with the
    /// previously presented destination and any associated state has been
    /// acquired and updated.
    /// ```swift
    /// Button("Next") {
    ///     Task { try? await navigator.next(flow) }
    /// }
    /// ```
    /// Next is async and throws in case any asynchronous work or error handling needs to be done. The terminal cases of ``FlowResult`` carry the flow itself, so any state the work mutated travels forward with the result.
    func next() async throws -> FlowResult<Self>

    /// Called when the flow completes successfully via ``FlowResult/complete(_:)``
    /// or ``Navigator/complete(_:)``.
    ///
    /// Use this hook for any cleanup or side effects you want to perform
    /// after the final destination has been handled. Note that this hook does
    /// not fire when the flow is completed with a typed value — use
    /// ``onComplete(_:)`` for that path.
    func onComplete()

    /// Called when the flow completes successfully with a typed return value
    /// via ``FlowResult/completeWithValue(_:_:)`` or
    /// ``Navigator/complete(_:returning:)``.
    ///
    /// The value has already been routed to the named checkpoint's handler at
    /// the time this hook fires. Override only if the flow itself needs to
    /// react to its own completion in addition to whatever the checkpoint
    /// handler does.
    func onComplete(_ value: Value)

    /// Called when the flow is cancelled before completion.
    ///
    /// Use this hook to revert transient state or record cancellation.
    func onCancel()

    /// Called when the flow encounters an unrecoverable error.
    ///
    /// Use this hook to log, surface, or otherwise handle the error.
    func onError(_ error: Error)

}

extension NavigationFlow {
    public func onComplete() {}
    public func onComplete(_ value: Value) {}
    public func onCancel() {}
    public func onError(_ error: Error) {}
}

extension NavigationFlow {
    /// Convenience function used to return a mutated copy of the object
    public func copy(mutate: (inout Self) -> Void) -> Self {
        var mutable = self
        mutate(&mutable)
        return mutable
    }
}

/// The result of advancing a ``NavigationFlow``.
///
/// A flow can either emit a new destination to navigate to, signal that it
/// has completed (optionally with a typed value), been cancelled, or failed
/// with an error.
public enum FlowResult<Flow: NavigationFlow> {
    /// Navigate to the provided destination.
    case destination(Flow.Destination)

    /// The flow has completed successfully without a return value.
    case complete(Flow)

    /// The flow has completed successfully with a value that should be routed
    /// to the named checkpoint's handler.
    ///
    /// Only meaningful when the flow's `checkpoint` was anchored to a named
    /// ``NavigationCheckpoint`` matching `Flow.Value`.
    case completeWithValue(Flow.Value, Flow)

    /// The flow was cancelled before completion.
    case cancel(Flow)

    /// The flow failed with the given error.
    case error(Flow, Error)
}

extension Navigator {

    /// Starts a navigation flow and navigates to its first destination.
    ///
    /// The navigator records an indexed checkpoint at the current navigator
    /// and path index so that the flow can return there on completion,
    /// cancellation, or error.
    ///
    /// ```swift
    /// navigator.start(OnboardingFlow())
    /// ```
    ///
    /// - Parameter flow: The flow to start.
    @MainActor public func start(_ flow: some NavigationFlow) {
        let copy = flow.copy { $0.checkpoint = .init(navigator: self) }
        dispatch(copy.start())
    }

    /// Starts a navigation flow anchored to a named user-facing checkpoint.
    ///
    /// On completion, the flow pops the navigation stack back to the named
    /// checkpoint and (for `complete(_:returning:)` / `.completeWithValue`)
    /// routes a value to the checkpoint's handler. The checkpoint's value type
    /// must match the flow's `Value`.
    ///
    /// ```swift
    /// navigator.start(ColorPickerFlow(), returningTo: KnownCheckpoints.selectedColor)
    /// ```
    ///
    /// - Parameters:
    ///   - flow: The flow to start.
    ///   - checkpoint: The named checkpoint to return to on flow termination.
    @MainActor public func start<F: NavigationFlow>(
        _ flow: F,
        returningTo checkpoint: NavigationCheckpoint<F.Value>
    ) {
        let copy = flow.copy { $0.checkpoint = .init(checkpoint) }
        dispatch(copy.start())
    }

    /// Advances a running navigation flow to its next step.
    ///
    /// - Parameter flow: The flow instance to advance.
    @MainActor
    public func next(_ flow: some NavigationFlow) async throws {
        dispatch(try await flow.next())
    }

    /// Private function routes a ``FlowResult`` to the matching navigator operation.
    ///
    /// Shared by ``start(_:)`` and ``next(_:)`` so the case-by-case
    /// dispatch lives in one place.
    @MainActor
    private func dispatch<F: NavigationFlow>(_ result: FlowResult<F>) {
        switch result {
        case .destination(let destination):
            navigate(to: destination)
        case .complete(let flow):
            complete(flow)
        case .completeWithValue(let value, let flow):
            complete(flow, returning: value)
        case .cancel(let flow):
            cancel(flow)
        case .error(let flow, let e):
            error(flow, error: e)
        }
    }

    /// Completes a navigation flow and returns to its checkpoint.
    ///
    /// Calls the flow's ``NavigationFlow/onComplete()`` hook after
    /// restoring the navigation stack. Does not route a value to a named
    /// checkpoint's handler — use ``complete(_:returning:)`` for that.
    @MainActor
    public func complete(_ flow: some NavigationFlow) {
        guard let (navigator, index, _) = flow.checkpoint?.resolve(from: self) else {
            log(.warning("flow checkpoint not found in current navigation tree"))
            return
        }
        navigator.returnToIndex(index)
        flow.onComplete()
    }

    /// Completes a navigation flow with a typed return value.
    ///
    /// Restores the navigation stack to the flow's checkpoint, routes `value`
    /// to the named checkpoint's handler via the navigation publisher (only
    /// for named-checkpoint anchors), then calls the flow's
    /// ``NavigationFlow/onComplete(_:)`` hook.
    ///
    /// - Parameters:
    ///   - flow: The flow instance to complete.
    ///   - value: The value to deliver to the checkpoint's handler.
    @MainActor
    public func complete<F: NavigationFlow>(_ flow: F, returning value: F.Value) {
        guard let (navigator, index, identifier) = flow.checkpoint?.resolve(from: self) else {
            log(.warning("flow checkpoint not found in current navigation tree"))
            return
        }
        navigator.returnToIndex(index)
        if let identifier {
            if let hashable = value as? any Hashable {
                publisher.send(NavigationSendValues(navigator: self, identifier: identifier, value: hashable))
            } else {
                log(.warning("flow value is not Hashable; cannot send to navigation publisher"))
            }
        }
        flow.onComplete(value)
    }

    /// Cancels a navigation flow and returns to its checkpoint.
    ///
    /// Calls the flow's ``NavigationFlow/onCancel()`` hook after
    /// restoring the navigation stack.
    @MainActor
    public func cancel(_ flow: some NavigationFlow) {
        guard let (navigator, index, _) = flow.checkpoint?.resolve(from: self) else {
            log(.warning("flow checkpoint not found in current navigation tree"))
            return
        }
        navigator.returnToIndex(index)
        flow.onCancel()
    }

    /// Ends a navigation flow because of an error and returns to its checkpoint.
    ///
    /// Calls the flow's ``NavigationFlow/onError(_:)`` hook after
    /// restoring the navigation stack.
    ///
    /// - Parameters:
    ///   - flow: The flow instance that failed.
    ///   - error: The error that occurred.
    @MainActor
    public func error(_ flow: some NavigationFlow, error: Error) {
        guard let (navigator, index, _) = flow.checkpoint?.resolve(from: self) else {
            log(.warning("flow checkpoint not found in current navigation tree"))
            return
        }
        navigator.returnToIndex(index)
        flow.onError(error)
    }

}

/// A checkpoint used to restore navigation state for a running flow.
///
/// Wraps either an indexed anchor (the navigator id and path index captured
/// when `start(_:)` was called) or a named anchor referencing a user-facing
/// ``NavigationCheckpoint``. The `Value` type matches the flow's `Value`
/// associated type and determines what payload can be routed back to a named
/// checkpoint's handler.
public struct NavigationFlowCheckpoint<Value>: Hashable, Sendable {

    private enum Storage: Hashable, Sendable {
        case indexed(id: UUID, index: Int)
        case named(name: String)
    }

    private let storage: Storage

    /// Anchors the flow to a specific navigator and path index.
    ///
    /// Used by ``Navigator/start(_:)`` to capture "where the user was when
    /// the flow began" so the flow can return there on completion. Available
    /// for any `Value` type — a typed flow with an indexed anchor will pop
    /// the stack on completion and call `onComplete(_:)` with the value, but
    /// there is no named handler to route the value to (indexed anchors don't
    /// have one).
    @MainActor
    internal init(navigator: Navigator) {
        self.storage = .indexed(id: navigator.id, index: navigator.count)
    }

    /// Anchors the flow to a named user-facing checkpoint that can receive a value.
    ///
    /// Used by ``Navigator/start(_:returningTo:)`` to install a named anchor
    /// so the flow's terminal value (if any) can be routed to the checkpoint's
    /// handler.
    public init(_ checkpoint: NavigationCheckpoint<Value>) {
        self.storage = .named(name: checkpoint.name)
    }

    /// Resolves this checkpoint to a concrete navigator, path index, and
    /// optional handler identifier.
    ///
    /// Returns nil when the underlying anchor can't be found in the current
    /// navigation tree (the named checkpoint was never mounted, or the
    /// indexed navigator has been torn down).
    @MainActor
    internal func resolve(from navigator: Navigator) -> (Navigator, Int, identifier: String?)? {
        switch storage {
        case .indexed(let id, let index):
            guard let found = navigator.find(id: id) else {
                return nil
            }
            return (found, index, nil)
        case .named(let name):
            guard let (found, entry) = navigator.findNamed(name) else {
                return nil
            }
            return (found, entry.index, entry.identifier)
        }
    }
}
