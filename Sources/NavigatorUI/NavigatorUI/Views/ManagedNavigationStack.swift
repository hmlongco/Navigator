//
//  ManagedNavigationStack.swift
//  Navigator
//
//  Created by Michael Long on 11/10/24.
//

import SwiftUI

/// Creates a NavigationStack and its associated Navigator that "manages" the stack.
///
/// Using ManagedNavigationStack is easy. Just use it where you'd normally used a `NavigationStack`.
/// ```swift
/// struct RootView: View {
///     var body: some View {
///         ManagedNavigationStack {
///             HomeView()
///         }
///     }
/// }
/// ```
/// ### Dismissible
/// Presented ManagedNavigationStacks are automatically dismissible.
/// ### State Restoration
/// ManagedNavigationStack supports state restoration out of the box. For state restoration to work, however, a
/// few conditions apply.
///
/// 1.  The ManagedNavigationStack must have a unique scene name.
/// 2.  All ``NavigationDestination`` types pushed onto the stack must be Codable.
/// 3.  A state restoration key was provided in ``NavigationConfiguration``.
///
/// See the State Restoration documentation for more.
@MainActor
public struct ManagedNavigationStack<Content: View>: View {

    @Environment(\.navigator) private var navigator: Navigator
    @Environment(\.isPresented) private var isPresented

    private let name: String?
    private let content: (Navigator) -> Content
    private let isScene: Bool

    /// Initializes NavigationStack.
    public init(@ViewBuilder content: @escaping () -> Content) {
        self.name = nil
        self.content = { _ in content() }
        self.isScene = false
    }

    /// Initializes NavigationStack passing Navigator into closure.
    public init(@ViewBuilder content: @escaping (Navigator) -> Content) {
        self.name = nil
        self.content = { navigator in content(navigator) }
        self.isScene = false
    }

    /// Initializes named NavigationStack.
    public init(name: String?, @ViewBuilder content: @escaping () -> Content) {
        self.name = name
        self.content = { _ in content() }
        self.isScene = false
    }

    /// Initializes named NavigationStack passing Navigator into closure.
    public init(name: String, @ViewBuilder content: @escaping (Navigator) -> Content) {
        self.name = name
        self.content = { navigator in content(navigator) }
        self.isScene = false
    }

    /// Initializes NavigationStack with name needed to enable scene storage.
    public init(scene name: String, @ViewBuilder content: @escaping () -> Content) {
        self.name = name
        self.content = { _ in content() }
        self.isScene = true
    }

    /// Initializes NavigationStack with name needed to enable scene storage passing Navigator into closure.
    public init(scene name: String, @ViewBuilder content: @escaping (Navigator) -> Content) {
        self.name = name
        self.content = { navigator in content(navigator) }
        self.isScene = true
    }

    /// The managed navigation stack that either uses an existing navigator
    /// (when wrapped in ``ManagedPresentationView``) or creates its own.
    public var body: some View {
        if isWrappedInPresentationView {
            WrappedNavigationStack(navigator: navigator.setting(name), sceneName: sceneName, content: content(navigator))
        } else {
            CreateNavigationStack(name: name, sceneName: sceneName, content: content)
        }
    }

    internal var isWrappedInPresentationView: Bool {
        isPresented && navigator.owner == .presenter
    }

    internal var sceneName: String? {
        isScene ? name : nil
    }

    // Allows NavigationStack to use Navigator provided by ManagedPresentationView
    internal struct WrappedNavigationStack: View {

        internal var navigator: Navigator
        internal let sceneName: String?
        internal let content: Content

        init(navigator: Navigator, sceneName: String?, content: Content) {
            self.navigator = navigator
            self.sceneName = sceneName
            self.content = content
        }

        var body: some View {
            NavigationStack(path: Bindable(navigator).path) {
                content
                    .navigationDestination(for: AnyNavigationDestination.self) { destination in
                        navigator.mappedNavigationView(for: destination.wrapped)
                    }
            }
            .modifier(NavigationSceneStorageModifier(navigator: navigator, name: sceneName))
            .onAppear {
                Navigator.current = navigator
            }
        }
    }

    // Allow NavigationStack to create and manage its own Navigator
    internal struct CreateNavigationStack: View {

        @Environment(\.navigator) private var parent
        @Environment(\.isPresented) private var isPresented
        @Environment(\.dismiss) private var dismiss

        @LazyState private var navigator: Navigator

        private let sceneName: String?
        private let content: (Navigator) -> Content

        init(name: String?, sceneName: String?, content: @escaping (Navigator) -> Content) {
            self._navigator = .init(wrappedValue: Navigator(owner: .stack, name: name))
            self.sceneName = sceneName
            self.content = content
        }

        var body: some View {
            let _ = {
                parent.addChild(navigator, dismissible: isPresented ? dismiss : nil)
            }()
            NavigationStack(path: Bindable(navigator).path) {
                content(navigator)
                    .navigationDestination(for: AnyNavigationDestination.self) { destination in
                        navigator.mappedNavigationView(for: destination.wrapped)
                    }
                    .environment(\.navigator, navigator)
            }
            .modifier(NavigationPresentationModifiers(navigator: navigator))
            .modifier(NavigationSceneStorageModifier(navigator: navigator, name: sceneName))
            .environment(\.navigator, navigator)
            .onAppear {
                Navigator.current = navigator
            }
        }
    }

}

// Navigator (Root)
// --Tab 1 - ManagedNavigationStack (Navigator)
// --Tab 2 - ManagedNavigationStack (Navigator)
// --Tab 3 - ManagedNavigationStack (Navigator)
// ----ManagedPresentationView (Navigator)
// ------ManagedNavigationStack (w/ManagedPresentationView's Navigator)
// --------ManagedPresentationView (Navigator)
// ----------ManagedNavigationStack (w/ManagedPresentationView's Navigator)

// RootNavigator
// - isPresented == false
//
// ManagedNavigationStack
// - isPresented == false
// - Needs New Navigator
// - Provides sheets
//
// -----------------------------
//
// PresentedView
// - isPresented == true
// - Provides New Navigator
// - Provides sheets
//
//   ManagedNavigationStack
//   - Uses Existing Navigator if PresentedView
//   - Uses Existing Sheets
//
// -----------------------------
//
// PresentedView
// - isPresented == true
// - Provides New Navigator
// - Provides sheets
//
//   ManagedNavigationStack
//   - Uses Existing Navigator
//   - Uses Existing Sheets
//
// -----------------------------
//
// PresentedView
// - isPresented == true
// - Provides New Navigator
// - Provides sheets
//
//   SomeView
//   - Uses Existing Navigator
//   - Uses Existing Sheets
//
