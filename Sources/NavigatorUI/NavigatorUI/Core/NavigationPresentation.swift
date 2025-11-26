//
//  NavigationPresentation.swift
//  Navigator
//
//  Created by Michael Long on 1/22/25.
//

import SwiftUI

extension Navigator {

    /// Convenience method resents a sheet/managed sheet.
    ///
    /// Managed attribute (wrapped in a ManagedNavigationStack) can be used to override NavigationDestination's default method. Otherwise
    /// the method will take its cue from the destination.method (true if method == .managedCover, false if anything else).
    @MainActor
    public func present(sheet destination: any NavigationDestination, managed: Bool? = nil) {
        if let managed {
            let method: NavigationMethod = managed ? .managedSheet : .sheet
            navigate(to: destination, method: method)
        } else if case .managedSheet = destination.method {
            navigate(to: destination, method: .managedSheet)
        } else {
            navigate(to: destination, method: .sheet)
        }
    }

    /// Convenience method resents a cover/managed cover.
    ///
    /// Managed attribute (wrapped in a ManagedNavigationStack) can be used to override NavigationDestination's default method. Otherwise
    /// the method will take its cue from the destination.method (true if method == .managedCover, false if anything else).
    @MainActor
    public func present(cover destination: any NavigationDestination, managed: Bool? = nil) {
        if let managed {
            let method: NavigationMethod = managed ? .managedCover : .cover
            navigate(to: destination, method: method)
        } else if case .managedCover = destination.method {
            navigate(to: destination, method: .managedCover)
        } else {
            navigate(to: destination, method: .cover)
        }
    }

    /// Returns true if the current ManagedNavigationStack or navigationDismissible is presenting.
    public nonisolated var isPresenting: Bool {
        state.isPresenting
    }

    /// Returns true if any child of the current ManagedNavigationStack or navigationDismissible is presenting.
    public nonisolated var isAnyChildPresenting: Bool {
        state.isAnyChildPresenting
    }

    /// Returns true if the current ManagedNavigationStack or navigationDismissible is presented.
    public nonisolated var isPresented: Bool {
        state.isPresented
    }

}

extension View {

    /// Allows presented views not in a navigation stack to be dismissed using a Navigator.
    ///
    /// Also supports nested sheets and covers.
    ///
    /// If you present sheets or covers in your own code, outside of `navigate(to:)`, and if those presented
    /// views don't use ``ManagedNavigationStack``, then `ManagedPresentationView`  tells Navigator about them.
    /// ```swift
    /// Button("Present Page 3 via Sheet") {
    ///     showSettings = .page3
    /// }
    /// .sheet(item: $showSettings) { destination in
    ///     destination()
    ///         .managedPresentationView()
    /// }
    /// ```
    /// That in turn allows them to be manipulated or closed when performing deep linking actions like dismissAny().
    ///
    /// This modifier is just a wrapper around ``ManagedPresentationView``.
    /// ```swift
    /// .sheet(item: $showSettings) { destination in
    ///     ManagedPresentationView {
    ///         destination()
    ///     }
    /// }
    /// ```
    /// > Warning: Failure to tag presented views as such can lead to inconsistent deep linking and navigation behavior.
    public func managedPresentationView() -> some View {
        ManagedPresentationView {
            self
        }
    }

}

extension NavigationState {

    internal nonisolated var isPresenting: Bool {
        children.values.first(where: { $0.object?.isPresented ?? false }) != nil
    }

    internal nonisolated var isAnyChildPresenting: Bool {
        children.values.first(where: {
            if let object = $0.object, object.isPresented || object.isAnyChildPresenting {
                return true
            }
            return false
        }) != nil
    }

}

internal struct NavigationPresentationModifiers: ViewModifier {

    @ObservedObject internal var state: NavigationState

    func body(content: Content) -> some View {
        content
            .sheet(item: $state.sheet) { (destination) in
                managedView(for: destination)
            }
            .fullScreenCover(item: $state.cover) { (destination) in
                managedView(for: destination)
            }
    }

    @ViewBuilder func managedView(for destination: AnyNavigationDestination) -> some View {
        ManagedPresentationView {
            if destination.method.requiresNavigationStack {
                ManagedNavigationStack {
                    state.mappedPresentationView(for: destination.wrapped)
                }
            } else {
                state.mappedPresentationView(for: destination.wrapped)
            }
        }
    }

}
