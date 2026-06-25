//
//  NavigationLink+Navigator.swift
//  NavigatorUI
//
//  Created by Michael Long on 9/10/25.
//

import SwiftUI

extension NavigationLink where Destination == Never {

    /// Creates a navigation link that pushes a ``NavigationDestination`` onto
    /// the current stack, integrating with ``ManagedNavigationStack`` and
    /// ``Navigator``.
    ///
    /// Use this initializer when the destination is a ``NavigationDestination``
    /// type so that NavigatorUI can present it correctly within a managed stack.
    ///
    /// ```swift
    /// struct ItemList: View {
    ///     var body: some View {
    ///         List(items) { item in
    ///             NavigationLink(to: ItemDestination.details(item)) {
    ///                 Text(item.title)
    ///             }
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - destination: The navigation destination to present when the link is tapped.
    ///   - label: A view builder that produces the link's label.
    @MainActor
    public init<D: NavigationDestination>(to destination: D, @ViewBuilder label: () -> Label) {
        self.init(value: AnyNavigationDestination(destination), label: label)
    }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension NavigationLink where Destination == Never, Label == Text {
    /// Creates a navigation link that presents a string title and pushes a
    /// ``NavigationDestination`` onto the current stack.
    ///
    /// This is a convenience for the common case of a text-only link, avoiding
    /// the need for a trailing label closure.
    ///
    /// ```swift
    /// struct ItemList: View {
    ///     var body: some View {
    ///         List(items) { item in
    ///             NavigationLink(item.title, to: ItemDestination.details(item))
    ///         }
    ///     }
    /// }
    /// ```
    @MainActor
    public init<S: StringProtocol, D: NavigationDestination>(_ title: S, to destination: D)  {
        self.init(title, value: AnyNavigationDestination(destination))
    }

    /// Creates a navigation link that presents a localized title and pushes a
    /// ``NavigationDestination`` onto the current stack.
    ///
    /// The key is looked up in the bundle's string table, so the title is
    /// localized for the current locale.
    ///
    /// ```swift
    /// struct ItemList: View {
    ///     var body: some View {
    ///         List(items) { item in
    ///             NavigationLink("View Details", to: ItemDestination.details(item))
    ///         }
    ///     }
    /// }
    /// ```
    @MainActor
    public init<D: NavigationDestination>(_ titleKey: LocalizedStringKey, to destination: D) {
        self.init(titleKey, value: AnyNavigationDestination(destination))
    }

    /// Creates a navigation link that presents a localized string resource and
    /// pushes a ``NavigationDestination`` onto the current stack.
    ///
    /// Use this initializer when the title comes from a `LocalizedStringResource`,
    /// such as a generated string catalog symbol, so the link participates in
    /// the same localization pipeline as the rest of your strings.
    ///
    /// ```swift
    /// extension LocalizedStringResource {
    ///     static let viewDetails = LocalizedStringResource("View Details", table: "Navigation")
    /// }
    ///
    /// struct ItemList: View {
    ///     var body: some View {
    ///         List(items) { item in
    ///             NavigationLink(.viewDetails, to: ItemDestination.details(item))
    ///         }
    ///     }
    /// }
    /// ```
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    @MainActor
    public init<D: NavigationDestination>(_ titleResource: LocalizedStringResource, to destination: D) {
        self.init(titleResource, value: AnyNavigationDestination(destination))
    }

}
