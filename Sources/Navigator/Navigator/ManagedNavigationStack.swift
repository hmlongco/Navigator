//
//  ManagedNavigationStack.swift
//  Navigator
//
//  Created by Michael Long on 11/10/24.
//

import SwiftUI

@MainActor
public struct ManagedNavigationStack<Content: View>: View {

    @Environment(\.navigator) private var parent: Navigator
    @Environment(\.isPresented) private var isPresented

    private var name: String?
    private var content: Content

    /// Initializes NavigationStack
    public init(@ViewBuilder content: () -> Content) {
        self.name = nil
        self.content = content()
    }

    public init(scene name: String, @ViewBuilder content: () -> Content) {
        self.name = name
        self.content = content()
    }

    public var body: some View {
        WrappedView(name: name, parent: parent, dismissible: isPresented, content: content)
    }

    // Wrapped view allows parent environment variables can be extracted and passed to navigator.
    private struct WrappedView: View {

        @StateObject private var navigator: Navigator
        @SceneStorage private var sceneStorage: Data?
        
        @Environment(\.dismiss) private var dismiss: DismissAction
        @Environment(\.scenePhase) private var scenePhase

        private let name: String?
        private let content: Content

        init(name: String?, parent: Navigator, dismissible: Bool, content: Content) {
            self.name = name
            self._sceneStorage = .init("ManagedNavigationStack.\(name ?? "")")
            self._navigator = .init(wrappedValue: .init(parent: parent, dismissible: dismissible))
            self.content = content
        }

        public var body: some View {
            NavigationStack(path: $navigator.path) {
                content
            }
            .onChange(of: navigator.triggerDismiss) { _ in
                dismiss()
            }
            .onChange(of: scenePhase) { phase in
                guard name != nil else {
                    return
                }
                if phase == .active, let data = sceneStorage {
                    navigator.restore(from: data)
                } else {
                    sceneStorage = navigator.encoded()
                }
            }
            .sheet(item: $navigator.sheet ) { destination in
                destination(navigator)
            }
            .fullScreenCover(item: $navigator.cover) { destination in
                destination(navigator)
            }
            .environment(\.navigator, navigator)
        }

    }

}
