//
//  TransitionExampleView.swift
//  NavigatorDemo
//
//  Created by Michael Long on 2/4/25.
//

import NavigatorUI
import SwiftUI

// 1. define a standard NavigationDestination enumeration
nonisolated enum TransitionDestinations: NavigationDestination {
    case destination1
    var body: some View {
        TransitionDestinationView()
    }
}

@available(iOS 18.0, *)
struct TransitionExampleView: View {
    var body: some View {
        ManagedNavigationStack {
            TransitionListView()
                .navigationTitle("Transition Example")
        }
    }
}

@available(iOS 18.0, *)
struct TransitionListView: View {
    // 2. define our namespace
    @Namespace var namespace
    @Environment(\.navigator) var navigator
    var body: some View {
        List {
            Section {
               // 3. use NavigationLink(to:label:) call
               NavigationLink(to: TransitionDestinations.destination1) {
                    Text("Trigger Transition")
                }
                // 4. define source
                .matchedTransitionSource(id: "zoom", in: namespace)
            }
            Button("Dismiss Example") {
                navigator.dismiss()
            }
        }
        // 5. use a navigationModifier to wrap our destination
        .navigationModifier { destination in
            // 5. expand destination to provide the needed destination view
            destination()
            // 6. add transition modifier
            .navigationTransition(.zoom(sourceID: "zoom", in: namespace))
        }
    }
}

struct TransitionDestinationView: View {
    @Environment(\.navigator) var navigator
    var body: some View {
        List {
            Button("Go Back") {
                navigator.back()
            }
        }
    }
}

@available(iOS 18.0, *)
#Preview {
    TransitionExampleView()
}
