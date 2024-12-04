//
//  Navigator.swift
//  Navigator
//
//  Created by Michael Long on 11/10/24.
//

import Combine
import SwiftUI

public class Navigator: ObservableObject {

    @Published internal var path: NavigationPath = .init() {
        didSet {
            cleanCheckpoints()
        }
    }

    @Published internal var sheet: AnyNavigationDestination? = nil
    @Published internal var cover: AnyNavigationDestination? = nil
    @Published internal var triggerDismiss: Bool = false

//    @Published public var custom: AnyNavigationDestination? = nil

    internal var configuration: NavigationConfiguration?

    internal weak var parent: Navigator?
    internal var children: [UUID : WeakObject<Navigator>] = [:]

    internal var id: UUID = .init()
    internal var checkpoints: [String: NavigationCheckpoint] = [:]
    internal var dismissible: Bool

    internal typealias NavigationSendValues = (value: any Hashable, values: [any Hashable])
    internal let publisher: PassthroughSubject<NavigationSendValues, Never>

    internal let decoder = JSONDecoder()
    internal let encoder = JSONEncoder()

    /// Allows public initialization of root Navigators.
    public init(configuration: NavigationConfiguration? = nil) {
        self.configuration = configuration
        self.container = configuration?.container ?? DefaultNavigationContainer()
        self.parent = nil
        self.publisher = .init()
        self.dismissible = false
        print("Navigator root: \(id)")
    }

    /// Internal initializer used by ManagedNavigationStack and navigationDismissible modifiers.
    internal init(parent: Navigator, dismissible: Bool) {
        self.configuration = parent.configuration
        self.container = parent.container
        self.parent = parent
        self.publisher = parent.publisher
        self.dismissible = dismissible
        parent.addChild(self)
        log("Navigator init: \(id) parent \(parent.id)")
     }

    /// Sentinel code removes child from parent when Navigator is dismissed.
    deinit {
        log("Navigator deinit: \(id)")
        parent?.removeChild(self)
    }

    /// Walks up the parent tree and returns the root Navigator.
    public var root: Navigator {
        parent?.root ?? self
    }

    public var container: NavigationContainer

    /// Adds a child Navigator to a parent Navigator.
    internal func addChild(_ child: Navigator) {
        children[child.id] = WeakObject(object: child)
    }

    /// Removes a child Navigator from a parent Navigator.
    internal func removeChild(_ child: Navigator) {
        children.removeValue(forKey: child.id)
    }

    /// Internal logging function.
    internal func log(_ message: @autoclosure () -> String) {
        #if DEBUG
        root.configuration?.logger?(message())
        #endif
    }

    /// Allows weak storage of reference types in arrays, dictionaries, and other collection types.
    internal struct WeakObject<T: AnyObject> {
        weak var object: T?
    }

}

extension Navigator {

    @MainActor
    public func navigate(to destination: any NavigationDestination) {
        navigate(to: destination, method: destination.method)
    }

    @MainActor
    public func navigate(to destination: any NavigationDestination, method method: NavigationMethod) {
        log("Navigator navigating to: \(destination) via: \(method)")
        switch method {
        case .push:
            push(destination)
        case .send:
            send(destination)
        case .sheet:
            sheet = AnyNavigationDestination(wrapped: destination)
        case .cover:
            cover = AnyNavigationDestination(wrapped: destination)
//        case .custom:
//            custom = AnyNavigationDestination(wrapped: destination)
        }
    }

}

extension Navigator {

    @MainActor
    public func push(_ destination: any NavigationDestination) {
        if let destination = destination as? any Hashable & Codable {
            path.append(destination) // ensures NavigationPath knows type is Codable
        } else {
            path.append(destination)
        }
    }

    @MainActor
    public func pop(to position: Int) {
        if position <= path.count {
            path.removeLast(path.count - position)
        }
    }

    @MainActor
    public func pop(last k: Int = 1) {
        if path.count >= k {
            path.removeLast(k)
        }
    }

    @MainActor
    public func popAll() {
        path.removeLast(path.count)
    }

    @MainActor
    public var isEmpty: Bool {
        path.isEmpty
    }

    @MainActor
    public var count: Int {
        path.count
    }

}

extension EnvironmentValues {
    /// Reference to the Navigator managing the current ManagedNavigationStack.
    @Entry public var navigator: Navigator = Navigator.defaultNavigator
}

extension Navigator {
    // Exists since EnvironmentValues loves to recreate default values
    nonisolated(unsafe) internal static let defaultNavigator: Navigator = Navigator()
}
