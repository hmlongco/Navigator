//
//  RootSplitView.swift
//  NavigatorDemo
//
//  Created by Michael Long on 1/25/25.
//

import NavigatorUI
import SwiftUI

struct RootSplitView: View {
    @State var selectedTab: RootTabs? = .home
    var body: some View {
        NavigationSplitView {
            SidebarView(selectedTab: $selectedTab)
                .navigationSplitViewColumnWidth(200)
        } detail: {
            selectedTab?()
        }
        .onNavigationReceive(assign: $selectedTab, delay: 0.8) // switching root views needs a little more time
        // set route handler for this view type
        .onNavigationRoute(RootSplitViewRouter())
        // set authentication root from which auth dialog will be presented
        .setAuthenticationRoot()
    }
}

private struct SidebarView: View {
    @Binding var selectedTab: RootTabs?
    var body: some View {
        List(selection: $selectedTab) {
            Section("Menu") {
                ForEach(RootTabs.sidebar) { tab in
                    NavigationLink(value: tab) {
                        Label(tab.title, systemImage: tab.image)
                    }
                }
            }
        }
    }
}

//private struct DetailView: View {
//    @Binding var selectedTab: RootTabs?
//    @StateObject private var homeRootViewModel = HomeRootViewModel()
//    var body: some View {
//        switch selectedTab {
//        case .home:
//            HomeRootView(viewModel: homeRootViewModel)
//        case .settings:
//            SettingsRootView()
//        case nil:
//            EmptyView()
//        }
//    }
//}

// Testing, bug
//struct SelectedTabView2: View {
//    @Binding var selectedTab: RootTabs
//    @StateObject private var homeRootViewModel = HomeRootViewModel()
//    var body: some View {
//        let _ = Self._printChanges()
//        TabView(selection: $selectedTab) {
//            HomeRootView(viewModel: homeRootViewModel)
//                .tabItem { Label("Home", systemImage: "house") }
//                .tag(RootTabs.home)
//                .toolbar(.hidden, for: .tabBar)
//            SettingsRootView()
//                .tabItem { Label("Settings", systemImage: "gear") }
//                .tag(RootTabs.settings)
//                .toolbar(.hidden, for: .tabBar)
//        }
//    }
//}
