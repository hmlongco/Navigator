//
//  NavigatorDemoLinks.swift
//  NavigatorDemo
//
//  Created by Michael Long on 11/21/24.
//

import Navigator
import SwiftUI

struct HomeURLHander: NavigationURLHander {
    @MainActor public func handles(_ url: URL) -> [any Hashable]? {
        guard url.pathComponents.count > 1, url.pathComponents[1] == "home" else {
            return nil
        }
        switch url.pathComponents.last {
        case "auth":
            // xcrun simctl openurl booted navigator://app/home/auth
            return [NavigationAction.dismissAll, RootTabs.home, NavigationAction.authenticationRequired, HomeDestinations.pageN(77)]
        case "page2":
            // xcrun simctl openurl booted navigator://app/home/page2
            return [NavigationAction.dismissAll, RootTabs.home, HomeDestinations.page2]
        case "page3":
            // xcrun simctl openurl booted navigator://app/home/page3
            return [NavigationAction.dismissAll, RootTabs.home, HomeDestinations.page3]
        default:
            // xcrun simctl openurl booted navigator://app/home
            return [NavigationAction.dismissAll, RootTabs.home]
        }
    }
}

struct SettingsURLHander: NavigationURLHander {
    @MainActor public func handles(_ url: URL) -> [any Hashable]? {
        guard url.pathComponents.count > 1, url.pathComponents[1] == "settings" else {
            return nil
        }
        return [NavigationAction.dismissAll, RootTabs.settings]
    }
}
