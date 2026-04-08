//
//  AnyNavigationDestination.swift
//  Navigator
//
//  Created by Michael Long on 11/10/24.
//

import SwiftUI

/// A type-erased wrapper around a specific ``NavigationDestination``.
///
/// `AnyNavigationDestination` stores both the underlying destination and the
/// ``NavigationMethod`` used to present it, allowing heterogeneous destinations
/// to be stored in a single `NavigationPath`.
public struct AnyNavigationDestination {

    /// The wrapped navigation destination.
    public var wrapped: any NavigationDestination

    /// The navigation method used to present the wrapped destination.
    public var method: NavigationMethod

    /// Defines a specific navigator name for presented sheets and covers.
    @MainActor public var presentationName: String? {
        wrapped.presentationName
    }

    @MainActor public var detents: Set<PresentationDetent> { wrapped.detents }
    @MainActor public var selectedDetent: PresentationDetent? { wrapped.selectedDetent }

    /// Creates a type-erased wrapper for the given destination.
    ///
    /// - Parameter destination: The destination to wrap. Its configured
    ///   ``NavigationDestination/method`` is captured at creation time.
    @MainActor
    public init<D: NavigationDestination>(_ destination: D) {
        self.wrapped = destination
        self.method = destination.method
    }

    internal init(wrapped: any NavigationDestination, method: NavigationMethod) {
        self.wrapped = wrapped
        self.method = method
    }
}

extension AnyNavigationDestination: Identifiable {

    /// An identifier derived from the wrapped destination's identifier.
    public nonisolated var id: Int { wrapped.id }

    /// Renders the wrapped destination as an `AnyView`.
    @MainActor public func callAsFunction() -> AnyView {
        wrapped.asAnyView()
    }

}

extension AnyNavigationDestination: Hashable, Equatable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }

    public static func == (lhs: AnyNavigationDestination, rhs: AnyNavigationDestination) -> Bool {
        lhs.id == rhs.id
    }

}

extension View {

    /// Enables/disables auto destination mode.
    /// ```swift
    /// // auto destination mode allows this..
    /// struct SettingsTabView: View {
    ///     var body: some View {
    ///         ManagedNavigationStack {
    ///             SettingsView()
    ///         }
    ///     }
    /// }
    ///
    /// // verses this...
    /// struct SettingsTabView: View {
    ///     var body: some View {
    ///         ManagedNavigationStack {
    ///             SettingsView()
    ///                 .navigationDestination(SettingsDestinations.self)
    ///                 .navigationDestination(ProfileDestinations.self)
    ///                 .navigationDestination(OptionsDestinations.self)
    ///         }
    ///     }
    /// }
    /// ```
    /// When enabled, explicit navigationDestination registrations are not required for any `NavigationDestination` type. Just navigate to
    /// that value.
    /// ```swift
    /// Button("Button Navigate to Page 55") {
    ///     navigator.navigate(to: UnregisteredDestination.pageN(55))
    /// }
    /// ```
    /// This even works with `NavigationLink` and pushed values. Just use `NavigationLink(to:label:)` in your code.
    /// ```swift
    /// import NavigatorUI
    ///
    /// NavigationLink(to: UnregisteredDestination.page3) {
    ///     Text("Link to Page 3!")
    /// }
    /// ```
    /// Just make sure you import NavigatorUI in your code.
    /// 
    /// You can also enable/disable auto destination mode for all managed navigation stacks in the configuration settings.
    /// ```swift
    /// @main
    /// struct NavigatorDemoApp: App {
    ///     let navigator = Navigator(configuration: .init(restorationKey: "1.0.0", autoDestinationMode: true)
    ///     var body: some Scene {
    ///         WindowGroup {
    ///             RootTabView()
    ///                 .navigationRoot(navigator)
    ///         }
    ///     }
    /// }
    /// ```
    @MainActor
    public func navigationAutoDestinationMode(_ enabled: Bool) -> some View {
        self.modifier(NavigationAutoDestinationModeModifier(enabled: enabled))
    }

}

private struct NavigationAutoDestinationModeModifier: ViewModifier {
    @Environment(\.navigator) private var navigator
    var enabled: Bool
    public func body(content: Content) -> some View {
        content
            .onAppear {
                navigator.autoDestinationModeOverride = enabled
            }
    }
}

extension AnyNavigationDestination: Codable {

    // Adapted from https://www.pointfree.co/blog/posts/78-reverse-engineering-swiftui-s-navigationpath-codability

    // convert data to NavigationDestination
    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()

        let typeName = try container.decode(String.self)
        guard let type = _typeByName(typeName) as? any Decodable.Type else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "\(typeName) is not decodable."
            )
        }

        guard let destination = try container.decode(type) as? any NavigationDestination else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "\(typeName) is not a NavigationDestination."
            )
        }

        let method = try container.decode(NavigationMethod.self)
        self.init(wrapped: destination, method: method)
    }

    // convert NavigationDestination to storable data
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        try container.encode(_mangledTypeName(type(of: wrapped)))

        guard let element = wrapped as? any Encodable else {
            let context = EncodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "\(type(of: wrapped)) is not encodable."
            )
            throw EncodingError.invalidValue(wrapped, context)
        }

        try container.encode(element)
        try container.encode(method)
    }
}
