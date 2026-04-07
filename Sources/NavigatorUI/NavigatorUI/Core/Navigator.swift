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
@MainActor
@Observable
public final class Navigator: @unchecked Sendable {

    /// Identifies who owns and manages a given navigator in the tree.
    public enum Owner: Int, Sendable {
        case application
        case root
        case stack
        case presenter
    }

    /// Errors that Navigator can throw
    public enum NavigationError: Error {
        case navigationLocked
    }

    /// Allows weak storage of reference types in arrays, dictionaries, and other collection types.
    internal struct WeakNavigator: Sendable {
        weak var object: Navigator?
    }

    // MARK: - Observable Properties

    /// Navigation path for the current ManagedNavigationStack
    internal var path: NavigationPath = .init() {
        didSet {
            cleanCheckpoints()
            isEmpty = path.isEmpty
            count = path.count
        }
    }

    /// Presentation trigger for .sheet navigation methods.
    internal var sheet: AnyNavigationDestination? = nil

    /// Presentation trigger for .cover navigation methods.
    internal var cover: AnyNavigationDestination? = nil

    /// Checkpoints managed by this navigation stack
    internal var checkpoints: [String: AnyNavigationCheckpoint] = [:]

    /// Navigation locks, if any
    internal var navigationLocks: Set<UUID> = []

    // MARK: - Observable Properties

    /// True if the current ManagedNavigationStack or navigationDismissible is presented.
    public internal(set) var isPresented: Bool = false

    /// True if the current ManagedNavigationStack or navigationDismissible is presenting a child.
    public internal(set) var isPresenting: Bool = false

    /// Empty path flag
    public internal(set) var isEmpty: Bool = false

    /// Number of items in the navigation path.
    public internal(set) var count: Int = 0

    // MARK: - Non-Observable Properties

    /// Persistent id of this navigator.
    @ObservationIgnored
    public let id: UUID = .init()

    /// Name of the current ManagedNavigationStack, if any.
    @ObservationIgnored
    public internal(set) var name: String? = nil

    /// Owner of this particular navigator.
    @ObservationIgnored
    public internal(set) var owner: Owner = .root

    /// Copy of the navigation configuration from the root view.
    @ObservationIgnored
    internal var configuration: NavigationConfiguration?

    /// Parent navigator, if any.
    @ObservationIgnored
    public internal(set) weak var parent: Navigator? = nil

    /// Presented children, if any.
    @ObservationIgnored
    internal var _children: [UUID : WeakNavigator] = [:]

    /// Dismissible function for this particular navigator.
    @ObservationIgnored
    internal var dismissAction: DismissAction?

    /// Navigation send publisher
    @ObservationIgnored
    internal var publisher: PassthroughSubject<NavigationSendValues, Never> = .init()

    /// Registered view providers
    @ObservationIgnored
    internal var navigationProviders: [ObjectIdentifier : Any] = [:]

    /// Use AnyNavigationDestination for all pushed NavigationDestination values, avoiding need to register destinations
    @ObservationIgnored
    internal var autoDestinationMode: Bool {
        autoDestinationModeOverride ?? configuration?.autoDestinationMode ?? true
    }

    /// set by NavigationAutoDestinationModeModifier
    @ObservationIgnored
    internal var autoDestinationModeOverride: Bool?

    /// Storage for .navigationMap modifier
    @ObservationIgnored
    internal var navigationMap: ((any NavigationDestination) -> any NavigationDestination)?
    @ObservationIgnored
    internal var navigationMapInherits: Bool = false

    /// Storage for .navigationModifier
    @ObservationIgnored
    internal var navigationModifier: ((any NavigationDestination) -> any View)?
    @ObservationIgnored
    internal var navigationModifierInherits: Bool = false

    /// Storage for .presentationModifier
    @ObservationIgnored
    internal var presentationModifier: ((any NavigationDestination) -> any View)?
    @ObservationIgnored
    internal var presentationModifierInherits: Bool = false

    // MARK: - Static Properties

    /// The currently active navigator
    nonisolated(unsafe) public static weak var current: Navigator?

    // MARK: - Computed Properties

    /// Determines whether or not users should see animation steps when deep linking.
    public var executionDelay: TimeInterval {
        configuration?.executionDelay ?? 0.6
    }

    /// Walks up the parent tree and returns the root Navigator.
    public var root: Navigator {
        parent?.root ?? self
    }

    /// Returns an array of any presented children.
    public var children: [Navigator] {
        _children
            .compactMap { $1.object }
    }

    // MARK: - Lifecycle

    /// Allows public initialization of root Navigators.
    public init(configuration: NavigationConfiguration) {
        self.name = "root"
        self.configuration = configuration
        log(.lifecycle(.configured))
    }

    /// Internal initializer used by ManagedNavigationStack and navigationDismissible modifiers.
    internal init(owner: Owner, name: String?) {
        self.owner = owner
        self.name = name
        // set as current
        Navigator.current = self
    }

    /// Sentinel code removes child from parent when Navigator is dismissed or deallocated.
    deinit {
        let parent = self.parent
        let child = self
        MainActor.assumeIsolated {
            child.log(.lifecycle(.deinit))
            parent?.removeChild(child)
            Navigator.current = parent
        }
    }

    // MARK: - Navigation tree support

    /// Adds a child navigator to parent.
    internal func addChild(_ child: Navigator, dismissible: DismissAction?) {
        // always update dismissible closure
        child.dismissAction = dismissible
        child.isPresented = dismissible != nil
        self.isPresenting = child.isPresented
        // exit if already added
        guard !_children.keys.contains(child.id) else {
            return
        }
        _children[child.id] = WeakNavigator(object: child)
        child.configuration = configuration
        child.parent = self
        child.publisher = publisher
        child.autoDestinationModeOverride = autoDestinationModeOverride
        child.navigationMap = navigationMapInherits ? navigationMap : nil
        child.navigationMapInherits = navigationMapInherits
        child.navigationModifier = navigationModifierInherits ? navigationModifier : nil
        child.navigationModifierInherits = navigationModifierInherits
        child.presentationModifier = presentationModifierInherits ? presentationModifier : nil
        child.presentationModifierInherits = presentationModifierInherits
        log(.lifecycle(.adding(child.id, name: child.name)))
    }

    /// Removes a child navigator from a parent.
    internal func removeChild(_ child: Navigator) {
        log(.lifecycle(.removing(child.id, name: child.name)))
        _children.removeValue(forKey: child.id)
        if child.isPresented {
            self.isPresenting = false
        }
        child.dismissAction = nil
    }

    /// Renames navigator for wrapped navigation stacks.
    @discardableResult
    internal func setting(_ name: String?) -> Navigator {
        self.name = name
        return self
    }

}

// MARK: - Hashable, Equatable

extension Navigator: Hashable, Equatable {

    /// Hashes the navigator using its unique identifier.
    nonisolated public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// Two navigators are equal when they share the same identifier.
    nonisolated public static func == (lhs: Navigator, rhs: Navigator) -> Bool {
        lhs.id == rhs.id
    }

}

// MARK: - Public Accessors

extension Navigator {

    /// Returns the root Navigator in the navigation tree.
    ///
    /// Note this navigation may not have a navigation stack associated with it.
    public var rootNavigator: Navigator {
        root
    }

    /// Returns the parent Navigator, if any, in the navigation tree.
    public var parentNavigator: Navigator? {
        parent
    }

    /// Returns the current Navigator that represents the current ManagedNavigationStack.
    ///
    /// Note this Navigator is defined when a given ManagedNavigationStack fires its "onAppear" handler, so it should be good for
    /// when a given Navigator first appears and when control returns to a given Navigator.
    public var currentNavigator: Navigator? {
        Navigator.current
    }

    /// Returns an array of any presented children.
    public var childNavigators: [Navigator] {
        _children
            .compactMap { $1.object }
    }

}

// MARK: - Environment

extension EnvironmentValues {
    /// Create environment entry for the Navigator managing the current ManagedNavigationStack.
    public var navigator: Navigator {
        get { self[NavigatorKey.self] }
        set { self[NavigatorKey.self] = newValue }
    }
}

@MainActor
private struct NavigatorKey: @preconcurrency EnvironmentKey {
    // Old-school approach avoids subtle bug in @Entry macro
    // https://michaellong.medium.com/debugging-swiftuis-entry-macro-e018a4974454
    static let defaultValue: Navigator = Navigator(owner: .application, name: nil)
}
