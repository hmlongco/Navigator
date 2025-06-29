//
//  SettingsDestinations.swift
//  Nav5
//
//  Created by Michael Long on 11/18/24.
//

import NavigatorUI
import SwiftUI

public enum SettingsDestinations: NavigationDestination, Codable {

    case page2
    case page3
    case sheet
    case external
    case presentLoading

    public var body: some View {
        switch self {
        case .page2:
            Page2SettingsView()
        case .page3:
            Page3SettingsView()
        case .sheet:
            SettingsSheetView()
        case .external:
            SettingsExternalView()
        case .presentLoading:
            PresentLoadingView()
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
