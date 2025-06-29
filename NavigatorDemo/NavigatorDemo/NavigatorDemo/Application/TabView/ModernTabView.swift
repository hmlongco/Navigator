//
//  ModernTabView.swift
//  Nav5
//
//  Created by Michael Long on 11/15/24.
//

import NavigatorUI
import SwiftUI

@available(iOS 18.0, macOS 15.0, tvOS 18.0, *)
struct ModernTabView : View {
    @SceneStorage("selectedTab") var selectedTab: RootTabs = .home
    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(RootTabs.tabs) { tab in
                Tab(tab.title, systemImage: tab.image, value: tab) {
                    tab()
                }
            }
        }
        // setup tab switching
        .onNavigationReceive { (tab: RootTabs) in
            if tab == selectedTab {
                return .immediately
            }
            selectedTab = tab
            return .after(0.7) // a little extra time after tab switch
        }
        // set route handler for this view type
        .onNavigationRoute(RootTabViewRouter())
        // set authentication root from which auth dialog will be presented
        .setAuthenticationRoot()
    }
}

@available(iOS 18.0, macOS 15.0, tvOS 18.0, *)
#Preview {
    ModernTabView()
}
