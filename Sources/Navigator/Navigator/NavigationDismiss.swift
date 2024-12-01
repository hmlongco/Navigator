//
//  NavigationDismiss.swift
//  Navigator
//
//  Created by Michael Long on 11/27/24.
//

import SwiftUI

extension Navigator {

    /// Dismisses the current ManagedNavigationStack or navigationDismissible if presented.
    @MainActor
    @discardableResult
    public func dismiss() -> Bool {
        if isPresented {
            triggerDismiss = true
            log("Navigator dimsissing: \(id)")
            return true
        }
        return false
    }

    /// Returns to the root Navigator and dismisses *any* presented ManagedNavigationStack.
    @MainActor
    @discardableResult
    public func dismissAll() -> Bool {
        root.dismissAllChildren()
    }

    /// Dismisses *any* ManagedNavigationStack or navigationDismissible presented by any child of this Navigator.
    @MainActor
    @discardableResult
    public func dismissAllChildren() -> Bool {
        for child in children.values {
            if let navigator = child.object, navigator.dismiss() || navigator.dismissAllChildren() {
                return true
            }
        }
        return false
    }

}

extension Navigator {

    /// Returns true if the current ManagedNavigationStack or navigationDismissible is presented.
    public nonisolated var isPresented: Bool {
        dismissible ?? false
    }

    /// Returns true if the current ManagedNavigationStack or navigationDismissible is presenting.
    public nonisolated var isPresenting: Bool {
        children.values.first(where: { $0.object?.isPresented ?? false }) != nil
    }

    /// Returns true if a child of the current ManagedNavigationStack or navigationDismissible is presenting.
    public nonisolated var isChildPresenting: Bool {
        children.values.first(where: { $0.object?.isPresented ?? false || $0.object?.isChildPresenting ?? false }) != nil
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
    public func navigationDismissAll(trigger: Binding<Bool>) -> some View {
        self.modifier(NavigationDismissModifierAll(trigger: trigger))
    }

}

private struct NavigationDismissModifier: ViewModifier {
    @Binding internal var trigger: Bool
    @Environment(\.navigator) internal var navigator: Navigator
    func body(content: Content) -> some View {
        content
            .onChange(of: trigger) { trigger in
                if trigger && navigator.dismiss() {
                    self.trigger = false
                }
            }
    }
}

private struct NavigationDismissModifierAll: ViewModifier {
    @Binding internal var trigger: Bool
    @Environment(\.navigator) internal var navigator: Navigator
    func body(content: Content) -> some View {
        content
            .onChange(of: trigger) { trigger in
                if trigger && navigator.dismissAll() {
                    self.trigger = false
                }
            }
    }
}
