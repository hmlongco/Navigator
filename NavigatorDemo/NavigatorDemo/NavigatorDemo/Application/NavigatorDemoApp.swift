//
//  NavigatorDemoApp.swift
//  NavigatorDemo
//
//  Created by Michael Long on 11/19/24.
//

import NavigatorUI
import SwiftUI

@main
struct NavigatorDemoApp: App {
    var body: some Scene {
        WindowGroup {
            ApplicationRootView()
        }
    }
}

struct ApplicationRootView: View {

    // SceneStorage must exist within a view
    @SceneStorage("appRootType") var appRootType: AppRootType = UIDevice.current.userInterfaceIdiom == .pad ? .split : .tabbed

    var body: some View {
        applicationView(AppResolver(navigator: applicationNavigator()))
    }

    func applicationNavigator() -> Navigator {
        let configuration: NavigationConfiguration = .init(
            restorationKey: nil, // "1.0.0",
            executionDelay: 0.4, // 0.3 - 5.0
            verbosity: .info
        )
        return Navigator(configuration: configuration)
    }

    func applicationView(_ resolver: AppResolver) -> some View {
        // Remember that modifiers wrap their parent view or parent modifiers, which means that they work from the outside in.
        // So here we're setting up dependencies first, then navigation, then url handlers.
        appRootType()
            // setup url handlers
            .onNavigationOpenURL(
                SimpleURLHandler(),
                HomeURLHandler(),
                SettingsURLHandler()
            )
            // toggle root view type
            .onNavigationReceive { (_: ToogleAppRootType) in
                self.appRootType = appRootType == .split ? .tabbed : .split
                return .auto
            }
            // setup navigation environment root
            .environment(\.navigator, resolver.navigator)
            // provide application dependencies
            .environment(\.coreDependencies, resolver)
            .environment(\.homeDependencies, resolver)
            .environment(\.settingsDependencies, resolver)
    }

}
