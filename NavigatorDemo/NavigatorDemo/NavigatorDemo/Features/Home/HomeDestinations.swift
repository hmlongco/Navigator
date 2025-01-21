//
//  TestPage.swift
//  Nav5
//
//  Created by Michael Long on 11/10/24.
//

import Navigator
import SwiftUI

public enum HomeDestinations {
    case home(String)
    case page2
    case page3
    case pageN(Int)
    case external
    case presented1
    case presented2
}

extension HomeDestinations: NavigationDestination {
    public var view: some View {
        // Illustrates external mapping of destination type to views. See Settings for simple mapping.
        HomeDestinationsView(destination: self)
    }
}

// External view mapping allows access to environment variables, in this case homeDependencies.
private struct HomeDestinationsView: View {
    // Destination to display
    let destination: HomeDestinations
    // Obtain core dependency resolver
    @Environment(\.homeDependencies) var resolver
    // Standard view body
    var body: some View {
        switch destination {
        case .home(let title):
            HomeContentView(title: title)
        case .page2:
            // Demonstrates method of injecting dependencies and building fully constructed view models
            HomePage2View(viewModel: HomePage2ViewModel(dependencies: resolver))
        case .page3:
            HomePage3View(initialValue: 66)
        case .pageN(let value):
            // Demonstrates passing resolver to view and letting it do what's needed.
            HomePageNView(dependencies: resolver, number: value)
        case .external:
            // Demonstrates getting view from unknown source
            resolver.homeExternalViewProvider().view(for: .external)
        case .presented1:
            // Demonstrates internally presented view via method
            NestedHomeContentView(title: "Via Sheet")
        case .presented2:
            // This presented view can not be globally dismissed via navigation action, deep links, etc.
            NestedHomeContentView(title: "Via Cover")
                .navigationLocked()
        }
    }
}

extension HomeDestinations {
    // not required but shows possibilities in predefining navigation destination types
    public var method: NavigationMethod {
        switch self {
        case .home, .page2, .page3, .pageN, .external:
            .push
        case .presented1:
            .sheet
        case .presented2:
            .cover
        }
    }
}
