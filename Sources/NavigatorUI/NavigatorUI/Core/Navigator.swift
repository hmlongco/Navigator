//
//  Navigator.swift
//  Navigator
//
//  Created by Michael Long on 11/10/24.
//

import Combine
import SwiftUI

/// Every ManagedNavigationStack has a Navigator to manage it.
///
/// Navigators enable imperative, programatic control of their associated navigation stacks,
/// ```swift
/// Button("Button Navigate to Home Page 55") {
///     navigator.navigate(to: HomeDestinations.pageN(55))
/// }
/// ```
/// Navigators work with other navigators in the navigation tree to enable global operations like
/// sending navigation values or returning to a parent's checkpoint.
/// ```swift
/// Button("Cancel") {
///     navigator.returnToCheckpoint(.home)
/// }
/// ```
/// Navigators are accessible from the environment. Just access them from within any view contained by
/// a ``ManagedNavigationStack``.
/// ```swift
/// @Environmnt(\.navigator) var navigator
/// ```
nonisolated public struct Navigator: @unchecked Sendable {

    internal let environmentID: Int
    internal let state: NavigationState

    public init(configuration: NavigationConfiguration) {
        let state = NavigationState(configuration: configuration)
        self.environmentID = state.hashValue
        self.state = state
    }

    internal init(owner: NavigationState.Owner, name: String? = nil) {
        self.state = NavigationState(owner: owner, name: name)
        self.environmentID = state.hashValue
    }

    internal init(state: NavigationState) {
        self.environmentID = state.hashValue
        self.state = state
    }

    internal init(state: NavigationState, parent: Navigator?, dismissible: DismissAction?) {
        self.environmentID = state.hashValue
        self.state = state
        parent?.state.addChild(state, dismissible: dismissible)
    }

    public var id: UUID {
        state.id
    }

    public var name: String? {
        state.name
    }

    /// Returns the root Navigator in the navigation tree.
    ///
    /// Note this navigation may not have a navigation stack associated with it.
    public var root: Navigator {
        Navigator(state: state.root)
    }

    /// Returns the parent Navigator, if any, in the navigation tree.
    public var parent: Navigator? {
        guard let state = state.parent else { return nil }
        return Navigator(state: state)
    }

    /// Returns the current Navigator that represents the current ManagedNavigationStack.
    ///
    /// Note this Navigator is defined when a given ManagedNavigationStack fires its "onAppear" handler, so it should be good for
    /// when a given Navigator first appears and when control returns to a given Navigator.
    public var current: Navigator? {
        guard let state = NavigationState.current else { return nil }
        return Navigator(state: state)
    }

    /// Returns an array of any presented children.
    public var children: [Navigator] {
        state.children
            .compactMap { $1.object }
            .map { Navigator(state: $0) }
    }

}

extension Navigator: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(state.id)
        hasher.combine(state.hashValue)
    }

    public static func == (lhs: Navigator, rhs: Navigator) -> Bool {
        lhs.id == rhs.id && lhs.hashValue == rhs.hashValue
    }

}

extension EnvironmentValues {
    /// Create environment entry for the Navigator managing the current ManagedNavigationStack.
    public var navigator: Navigator {
        get { self[NavigatorKey.self] }
        set { self[NavigatorKey.self] = newValue }
    }
}

private struct NavigatorKey: EnvironmentKey {
    // Old-school approach avoids subtle bug in @Entry macro
    // https://michaellong.medium.com/debugging-swiftuis-entry-macro-e018a4974454
    static let defaultValue: Navigator = Navigator(owner: .application)
}
