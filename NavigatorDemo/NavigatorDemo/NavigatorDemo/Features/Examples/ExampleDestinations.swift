//
//  ExampleDestinations.swift
//  NavigatorDemo
//
//  Created by Michael Long on 2/4/25.
//

import NavigatorUI
import SwiftUI

nonisolated public enum ExampleDestinations: String, NavigationDestination, CaseIterable {

    case flows
    case binding
    case callback
    case transition

    public var body: some View {
        switch self {
        case .binding:
            BindingExampleView()
        case .callback:
            CallbackExampleView()
        case .flows:
            FlowExampleView()
        case .transition:
            if #available(iOS 18.0, *) {
                TransitionExampleView()
            } else {
                NotAvailableView()
            }
        }
    }

    public var method: NavigationMethod {
        .cover
    }

    public var title: String {
        rawValue.capitalized
    }

    public var description: String {
        switch self {
        case .binding:
            "Demonstrates using a binding in navigation destinations."
        case .callback:
            "Demonstrates using callback handlers and checkpoints in navigation destinations."
        case .flows:
            "Demonstrates using NavigationFlows."
        case .transition:
            "Demonstrates custom transitions with navigation destinations. (iOS 18.0+)"
        }
    }

}

private struct NotAvailableView: View {
    @Environment(\.navigator) var navigator
    var body: some View {
        List {
            Text("Not Available")
            Button("Dismiss") {
                navigator.dismiss()
            }
        }
    }
}
