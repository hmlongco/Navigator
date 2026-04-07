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

    /// Returns true if any child of the current ManagedNavigationStack or navigationDismissible is presenting.
    public func isAnyChildPresenting() -> Bool {
        _children.values.first(where: {
            if let object = $0.object, object.isPresented || object.isAnyChildPresenting() {
                return true
            }
            return false
        }) != nil
    }

    /// Returns NavigationDestination of sheet or cover we're currently presenting, if any.
    public var presentingSheetOrCover: (any NavigationDestination)? {
        (sheet ?? cover)?.wrapped as? NavigationDestination
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
    public func managedPresentationView(name: String? = nil) -> some View {
        ManagedPresentationView(name: name) {
            self
        }
    }

}

internal struct NavigationPresentationModifiers: ViewModifier {

    internal var navigator: Navigator

    func body(content: Content) -> some View {
        @Bindable var nav = navigator
        content
            .sheet(item: $nav.sheet) { (destination) in
                managedView(for: destination)
                    .modifier(PresentationDetentsModifier(
                        detents: destination.detents,
                        initialSelection: destination.selectedDetent
                    ))
            }
            #if os(iOS) || os(tvOS) || os(watchOS)
            .fullScreenCover(item: $nav.cover) { (destination) in
                managedView(for: destination)
            }
            #endif
    }

    @ViewBuilder func managedView(for destination: AnyNavigationDestination) -> some View {
        ManagedPresentationView {
            if destination.method.requiresNavigationStack {
                ManagedNavigationStack {
                    navigator.mappedPresentationView(for: destination.wrapped)
                }
            } else {
                navigator.mappedPresentationView(for: destination.wrapped)
            }
        }
    }

}

/// Applies `.presentationDetents()` conditionally based on destination configuration.
///
/// When detents are provided, they constrain the sheet to the specified sizes.
/// When a selected detent is provided, the sheet opens at that size initially.
internal struct PresentationDetentsModifier: ViewModifier {

    let detents: Set<PresentationDetent>
    let initialSelection: PresentationDetent?

    @State private var selectedDetent: PresentationDetent = .large

    func body(content: Content) -> some View {
        if detents.isEmpty {
            content
        } else if initialSelection != nil {
            content
                .presentationDetents(detents, selection: $selectedDetent)
                .onAppear {
                    if let initialSelection {
                        selectedDetent = initialSelection
                    }
                }
        } else {
            content
                .presentationDetents(detents)
        }
    }

}
