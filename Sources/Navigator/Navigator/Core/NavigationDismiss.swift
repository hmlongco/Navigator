//
//  NavigationDismiss.swift
//  Navigator
//
//  Created by Michael Long on 11/27/24.
//

import SwiftUI

extension Navigator {

    /// Dismisses the currently presented ManagedNavigationStack.
    @MainActor
    @discardableResult
    public func dismiss() -> Bool {
        state.dismiss()
    }

    /// Dismisses presented sheet or fullScreenCover views presented by this Navigator.
    @MainActor
    public func dismissPresentedViews() {
        state.sheet = nil
        state.cover = nil
    }

    /// Returns to the root Navigator and dismisses *any* presented ManagedNavigationStack.
    @MainActor
    @discardableResult
    public func dismissAny() throws -> Bool {
        try state.dismissAny()
    }

    /// Dismisses *any* ManagedNavigationStack or navigationDismissible presented by any child of this Navigator.
    @MainActor
    @discardableResult
    public func dismissAll() -> Bool {
        state.dismissAll()
    }

}

extension View {

    /// Dismisses the current ManagedNavigationStack or navigationDismissible if presented.
    ///
    /// Trigger value will be reset to false on dismissal.
    public func navigationDismiss(trigger: Binding<Bool>) -> some View {
        self.modifier(NavigationDismissModifier(trigger: trigger))
    }

    /// Returns to the root Navigator and dismisses *any* presented ManagedNavigationStack.
    ///
    /// Trigger value will be reset to false on dismissal.
    public func navigationDismissAny(trigger: Binding<Bool>) -> some View {
        self.modifier(NavigationDismissAnyModifier(trigger: trigger))
    }

    /// Allows presented views not in a navigation stack to be dismissed using a Navigator.
    @available(*, deprecated, renamed: "managedPresentationView", message: "Use `managedPresentationView()` instead.")
    public func navigationDismissible() -> some View {
        ManagedPresentationView {
            self
        }
    }

}

extension NavigationState {

    internal func dismiss() -> Bool {
        if isPresented {
            triggerDismiss = true
            log("Navigator dimsissing: \(id)")
            return true
        }
        return false
    }

    /// Returns to the root Navigator and dismisses *any* presented ManagedNavigationStack.
    internal func dismissAny() throws -> Bool {
        guard !isNavigationLocked else {
            log(type: .warning, "Navigator \(id) error navigation locked")
            throw NavigationError.navigationLocked
        }
        return root.dismissAll()
    }

    internal func dismissAll() -> Bool {
        for child in children.values {
            if let childNavigator = child.object {
                if #available (iOS 18.0, *) {
                    if childNavigator.dismiss() || childNavigator.dismissAll() {
                        return true
                    }
                } else {
                    var dismissed: Bool
                    // both functions need to execute, || would short-circuit
                    dismissed = childNavigator.dismissAll()
                    dismissed = childNavigator.dismiss() || dismissed
                    if dismissed {
                        return true
                    }
                }
            }
        }
        return false
    }

}

private struct NavigationDismissModifier: ViewModifier {
    @Binding internal var trigger: Bool
    @Environment(\.navigator) internal var navigator: Navigator
    func body(content: Content) -> some View {
        content
            .onChange(of: trigger) { trigger in
                if trigger {
                    self.trigger = false
                    navigator.dismiss()
                }
            }
    }
}

private struct NavigationDismissAnyModifier: ViewModifier {
    @Binding internal var trigger: Bool
    @Environment(\.navigator) internal var navigator: Navigator
    func body(content: Content) -> some View {
        content
            .onChange(of: trigger) { trigger in
                if trigger {
                    self.trigger = false
                    _ = try? navigator.dismissAny()
               }
            }
    }
}
