//
//  NavigationContainer.swift
//  Navigator
//
//  Created by Michael Long on 12/3/24.
//

import SwiftUI

public protocol NavigationContainer {
    // empty protocol
}

internal struct DefaultNavigationContainer: NavigationContainer {
    // does nothing
}

extension View {

    public func navigationContainer(_ container: any NavigationContainer) -> some View {
        self.modifier(NavigationContainerModifier(container: container))
    }

}

private struct NavigationContainerModifier: ViewModifier {
    internal let container: any NavigationContainer
    @Environment(\.navigator) internal var navigator: Navigator
    func body(content: Content) -> some View {
        content.modifier(WrappedModifier(container: container, navigator: navigator))
    }
    struct WrappedModifier: ViewModifier {
        init(container: any NavigationContainer, navigator: Navigator) {
            navigator.container = container
        }
        func body(content: Content) -> some View {
            content
        }
    }
}
