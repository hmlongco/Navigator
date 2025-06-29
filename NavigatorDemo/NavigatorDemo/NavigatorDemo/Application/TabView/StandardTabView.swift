//
//  TabView.swift
//  Nav5
//
//  Created by Michael Long on 11/15/24.
//

import NavigatorUI
import SwiftUI

struct StandardTabView : View {
    @SceneStorage("selectedTab") var selectedTab: RootTabs = .home
    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(RootTabs.tabs) { tab in
                tab()
                    .tabItem { Label(tab.title, systemImage: tab.image) }
                    .tag(tab)
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

#Preview {
    StandardTabView()
}
