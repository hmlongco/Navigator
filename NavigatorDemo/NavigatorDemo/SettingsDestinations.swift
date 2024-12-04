//
//  SettingsDestinations.swift
//  Nav5
//
//  Created by Michael Long on 11/18/24.
//

import Navigator
import SwiftUI

public enum SettingsDestinations: Int, Codable {
    case page2
    case page3
    case sheet
}

protocol MyContainer {

}

extension SettingsDestinations: NavigationDestination {
    public func view(_ navigator: Navigator) -> some View {
        switch self {
        case .page2:
            Page2SettingsView()
        case .page3:
            Page3SettingsView()
        case .sheet:
            SettingsSheetView()
                .navigationDismissible()
        }
    }
    public var method: NavigationMethod {
        switch self {
        case .sheet:
            .sheet
        default:
            .push
        }
    }
}
