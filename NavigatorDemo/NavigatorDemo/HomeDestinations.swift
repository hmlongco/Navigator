//
//  TestPage.swift
//  Nav5
//
//  Created by Michael Long on 11/10/24.
//

import Navigator
import SwiftUI

public enum HomeDestinations: Codable {
    case page2
    case page3
    case pageN(Int)
    case presented1
    case presented2
}

extension HomeDestinations: NavigationDestination {
    public func view(_ navigator: Navigator) -> some View {
        switch self {
        case .page2:
            HomePage2View()
        case .page3:
            HomePage3View()
        case .pageN(let value):
            HomePageNView(number: value)
        case .presented1:
            NestedHomeContentView(title: "Via Sheet")
        case .presented2:
            NestedHomeContentView(title: "Via Cover")
        }
    }
}

extension HomeDestinations {
    // not required but shows possibilities in predefining navigation destination types
    public var method: NavigationMethod {
        switch self {
        case .page2, .page3, .pageN:
            .push
        case .presented1:
            .sheet
        case .presented2:
            .cover
        }
    }
}
