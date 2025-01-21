//
//  SettingsDestinations.swift
//  Nav5
//
//  Created by Michael Long on 11/18/24.
//

import Navigator
import SwiftUI

public enum SettingsDestinations: Int {
    case page2
    case page3
    case sheet
    case external
    case presentLoading
}

extension SettingsDestinations: NavigationDestination {
    // Illustrates simple embedded mapping of destination type to views. See Home for more complex example.
    public var view: some View {
        switch self {
        case .page2:
            Page2SettingsView()
        case .page3:
            Page3SettingsView()
        case .sheet:
            SettingsSheetView()
                .navigationDismissible()
        case .external:
            SettingsExternalView()
        case .presentLoading:
            ManagedNavigationStack {
                PresentLoadingView()
            }
        }
    }
    public var method: NavigationMethod {
        switch self {
        case .presentLoading, .sheet:
            .sheet
        default:
            .push
        }
    }
    public var receiveResumeType: NavigationReceiveResumeType {
        switch self {
        case .presentLoading:
            .pause // pause sending after presenting this view
        default:
            .auto
        }
    }
}

public enum LoadingDestinations: Int, Codable {
    case external
}

extension LoadingDestinations: NavigationDestination {
    public var view: some View {
        switch self {
        case .external:
            SettingsExternalView()
        }
    }
//    public var method: NavigationMethod {
//        switch self {
//        case .external:
//            .sheet
//        }
//    }
}
