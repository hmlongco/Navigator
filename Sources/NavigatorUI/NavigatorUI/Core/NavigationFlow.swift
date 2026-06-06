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

    associatedtype Destination: NavigationDestination

    /// Optional checkpoint used by the `Navigator` to restore the navigation
    /// stack to the flow's starting point when it completes, is cancelled,
    /// or encounters an error.
    var checkpoint: NavigationFlowCheckpoint? { get set }

    /// Starts the flow and returns the first navigation result.
    ///
    /// Use this to emit the initial destination or signal that the flow
    /// is already complete, cancelled, or in error.
    func start() -> FlowResult<Destination>

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
    /// Next is async and throws in case any asynchronous work or error handling needs to be done, and it also returns an instance of itself in case that work mutates the flow state even further.
    ///
    /// (See the `copy` function.)
    func next() async throws -> (Self, FlowResult<Destination>)

    /// Called when the flow completes successfully.
    ///
    /// Use this hook for any cleanup or side effects you want to perform
    /// after the final destination has been handled.
    func onComplete()

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
/// has completed, been cancelled, or failed with an error.
public enum FlowResult<Destination> {
    /// Navigate to the provided destination.
    case destination(Destination)
    /// The flow has completed successfully.
    case complete
    /// The flow was cancelled before completion.
    case cancel
    /// The flow failed with the given error.
    case error(Error)
}

extension Navigator {

    /// Starts a navigation flow and navigates to its first destination.
    ///
    /// The navigator records a checkpoint so that it can return to the
    /// starting point when the flow completes, is cancelled, or errors.
    ///
    /// ```swift
    /// struct OnboardingFlow: NavigationFlow {
    ///     struct Step: NavigationDestination { /* ... */ }
    ///
    ///     var checkpoint: NavigationFlowCheckpoint?
    ///
    ///     func start() -> FlowResult<Step> { .destination(.welcome) }
    ///     mutating func next() -> FlowResult<Step> { /* advance flow */ }
    /// }
    ///
    /// navigator.start(OnboardingFlow())
    /// ```
    ///
    /// - Parameter flow: The flow to start.
    @MainActor public func start(_ flow: some NavigationFlow) {
        var copy = flow
        copy.checkpoint = .init(id: id, index: count)
        switch copy.start() {
        case .destination(let destination):
            navigate(to: destination)
        case .complete:
            complete(copy)
        case .cancel:
            cancel(copy)
        case .error(let e):
            error(copy, error: e)
        }
    }

    /// Advances a running navigation flow to its next step.
    ///
    /// - Parameter flow: The flow instance to advance.
    @MainActor
    public func next(_ flow: some NavigationFlow) async throws {
        let (copy, result) = try await flow.next()
        switch result {
        case .destination(let destination):
            navigate(to: destination)
        case .complete:
            complete(copy)
        case .cancel:
            cancel(copy)
        case .error(let e):
            error(copy, error: e)
        }
    }

    /// Completes a navigation flow and returns to its checkpoint.
    ///
    /// Calls the flow's ``NavigationFlow/onComplete()`` hook after
    /// restoring the navigation stack.
    @MainActor
    public func complete(_ flow: some NavigationFlow) {
        guard let checkpoint = flow.checkpoint else { return }
        if let navigator = find(id: checkpoint.id) {
            navigator.returnToIndex(checkpoint.index)
            flow.onComplete()
        }
    }

    /// Cancels a navigation flow and returns to its checkpoint.
    ///
    /// Calls the flow's ``NavigationFlow/onCancel()`` hook after
    /// restoring the navigation stack.
    @MainActor
    public func cancel(_ flow: some NavigationFlow) {
        guard let checkpoint = flow.checkpoint else { return }
        if let navigator = find(id: checkpoint.id) {
            navigator.returnToIndex(checkpoint.index)
            flow.onCancel()
        }
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
        guard let checkpoint = flow.checkpoint else { return }
        if let navigator = find(id: checkpoint.id) {
            navigator.returnToIndex(checkpoint.index)
            flow.onError(error)
        }
    }

}

/// A checkpoint used to restore navigation state for a running flow.
///
/// This typealias gives a domain-specific name to ``IndexedNavigationCheckpoint``,
/// which tracks both the `Navigator` identifier and the index within its path.
public typealias NavigationFlowCheckpoint = IndexedNavigationCheckpoint

/// An internal representation of a flow checkpoint tied to a specific `Navigator`.
@MainActor
public struct IndexedNavigationCheckpoint: Hashable, Equatable {
    internal let id: UUID
    internal let index: Int
}
