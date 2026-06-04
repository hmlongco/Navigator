//
//  BindingExampleView.swift
//  Navigator
//
//  Created by Michael Long on 2/12/25.
//

import NavigatorUI
import SwiftUI

struct BindingExampleView: View {
    @State var value: Double = 0
    var body: some View {
        ManagedNavigationStack { navigator in
            List {
                Section {
                    Text("Current Value: \(Int(value))")
                    Slider(value: $value, in: 1...10, step: 1)
                }
                Section {
                    Button("Present Bound Sheet") {
                        navigator.navigate(to: Destinations.destination1($value), method: .sheet)
                    }
                    Button("Dismiss Example") {
                        navigator.dismiss()
                    }
                }
            }
            .navigationTitle("Binding Example")
        }
    }
}

extension BindingExampleView {
    nonisolated enum Destinations: NavigationDestination {
        case destination1(Binding<Double>)
        var body: some View {
            switch self {
            case .destination1(let binding):
                PresentedBindingExampleView(value: binding)
            }
        }
    }
}

struct PresentedBindingExampleView: View {
    @Binding var value: Double
    var body: some View {
        ManagedNavigationStack { navigator in
            List {
                Section {
                    Text("Bound Value: \(Int(value))")
                    Slider(value: $value, in: 1...10, step: 1)
                }
                Button("Dismiss Example") {
                    navigator.dismiss()
                }
            }
            .navigationTitle("Binding Example")
        }
    }

}
