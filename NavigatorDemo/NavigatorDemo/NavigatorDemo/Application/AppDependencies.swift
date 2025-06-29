//
//  AppDependencies.swift
//  NavigatorDemo
//
//  Created by Michael Long on 1/24/25.
//

import NavigatorUI
import SwiftUI

//
// APPLICATION DEPENDENCY RESOLVER
//

// Application aggregates all known module dependencies
protocol AppDependencies: CoreDependencies
    & HomeDependencies
    & SettingsDependencies
{}

// Make the application's dependency resolver
class AppResolver: AppDependencies {

    // root navigator
    let navigator: Navigator

    // ensure we have dependency cache in scope
    let cache: DependencyCache = .init()

    // initializer
    init(navigator: Navigator) {
        self.navigator = navigator
    }

    // Missing default dependencies forces app to provide them.
    var analytics: any AnalyticsService {
        singleton { ThirdPartyAnalyticsService() as any AnalyticsService }
    }

    // Home needs an external view from somewhere. Provide it.
    @MainActor public var homeExternalViewProvider: any NavigationViewProviding<HomeExternalViews> {
        NavigationViewProvider {
            switch $0 {
            case .external:
                SettingsDestinations.external()
            }
        }
    }

    // Home feature wants to be able to route to settings feature, app knows how app is structured, so...
    @MainActor var homeExternalRouter: any NavigationRouting<HomeExternalRoutes> {
        NavigationRouter(navigator) { route in
            // Map external routes required by Home feature to known application routes
            switch route {
            case .settingsPage2:
                self.navigator.perform(route: KnownRoutes.settingsPage2)
            case .settingsPage3:
                self.navigator.perform(route: KnownRoutes.settingsPage3)
            }
        }
    }
    
    // Missing default provides proper key
    var settingsKey: String { "actual" }
}
