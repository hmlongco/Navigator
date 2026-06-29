//
//  NavigationProvidedView.swift
//  NavigatorUI
//
//  Created by Michael Long on 9/28/25.
//

import SwiftUI

/// Implements the mechanism behind `NavigationProvidedDestination`.
///
/// This modifier can be used on its own, particularly if you want to provide your own set of
/// placeholder views for the views to be provided later.
/// ```swift
/// nonisolated public enum SharedDestinations: NavigationDestination {
///     case newOrder
///     case orderDetails(Order)
///     case produceDetails(Product)
///
///     public var body: some View {
///         NavigationProvidedView(for: self) {
///             switch self {
///             case .newOrder:
///                 MockNewOrderView()
///             case .orderDetails(let order):
///                 MockOrderDetailsView(order)
///             case .produceDetails(let product):
///                 MockProduceDetailsView(for: product)
///             }
///         }
///     }
/// }
/// ```
public struct NavigationProvidedView<D: NavigationDestination, P: View>: View {
    @Environment(\.navigator) private var navigator
    
    private let destination: D
    private let placeholder: P?

    /// Creates a provided view that resolves the given destination using
    /// any registered `onNavigationProvidedView` handlers.
    ///
    /// When no provider is available, a debug-only placeholder message is shown.
    public init(for destination: D) where P == EmptyView {
        self.destination = destination
        self.placeholder = nil
    }

    /// Creates a provided view with a custom placeholder.
    ///
    /// The placeholder content is shown whenever no provider is available
    /// for the destination.
    ///
    /// - Parameters:
    ///   - destination: The destination to resolve.
    ///   - placeholder: A view builder that returns placeholder content.
    public init(for destination: D, @ViewBuilder placeholder: @escaping () -> P) {
        self.destination = destination
        self.placeholder = placeholder()
    }

    /// The resolved destination view, a placeholder view, or an empty view.
    public var body: some View {
        if let view = navigator.navigationProvidedView(for: destination) {
            AnyView(view)
        } else if let placeholder {
            placeholder
        } else {
            #if DEBUG
            Text(verbatim: "Missing Provider for \(type(of: self)).\(self)")
            #else
            EmptyView()
            #endif
        }
    }
}
