//
//  ContentView.swift
//  Nav5
//
//  Created by Michael Long on 11/10/24.
//

import NavigatorUI
import SwiftUI

struct CustomContentView: View {
    @Environment(\.navigator) var navigator: Navigator
    var body: some View {
        List {
            ContentSheetSection()
        }
    }
}

struct ContentSheetSection: View {
    @Environment(\.navigator) var navigator: Navigator
    @State var showSheet: Bool = false
    @State var dismissFlag: Bool = false
    @State var dismissAny: Bool = false
    @State var presentSheet: HomeDestinations?
    @State var presentCover: HomeDestinations?
    var body: some View {
        Section("Presentation Actions") {
            Button("Present On Current Navigator (5s)") {
                Task {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    navigator.current?.navigate(to: HomeDestinations.presented1)
                }
            }

            Button("Present Sheet (Imperative)") {
                navigator.navigate(to: HomeDestinations.presented1)
                if let d = navigator.presentingSheetOrCover as? HomeDestinations, d == .presented1 {
                    print("HomeDestinations.presented1 is the current destination")
                }
            }

            Button("Present Sheet (Declarative)") {
                presentSheet = HomeDestinations.presented1
            }
            .navigate(to: $presentSheet)

            Button("Present Sheet as Cover (Declarative)") {
                presentCover = HomeDestinations.presented1
            }
            .navigate(to: $presentCover, method: .cover)

            Button("Present Locked Cover (Imperative)") {
                navigator.navigate(to: HomeDestinations.presented2)
                navigator.returnToCheckpoint(KnownCheckpoints.home)
            }

            Button("Present Dismissible View") {
                showSheet = true
            }
            .sheet(isPresented: $showSheet) {
                CustomContentView()
                    .managedPresentationView()
            }

            Button("Present Root Sheet") {
                navigator.send(AppRootDestinations.demo)
            }

            Button("Dismiss via Navigator", role: .cancel) {
                navigator.dismiss()
            }
            .disabled(!navigator.isPresented)

            Button("Dismiss via NavigationDismiss", role: .cancel) {
                dismissFlag = true
            }
            .navigationDismiss(trigger: $dismissFlag)
            .disabled(!navigator.isPresented)

            Button("Dismiss w/o Animation", role: .cancel) {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                _ = withTransaction(transaction) {
                    navigator.dismiss()
                }
            }
            .disabled(!navigator.isPresented)

            Button("Dismiss Any") {
                dismissAny = true
            }
            .navigationDismissAny(trigger: $dismissAny)
            .disabled(!navigator.isPresented)
        }
    }
}

struct ContentCheckpointSection: View {
    @Environment(\.navigator) var navigator: Navigator
    @Environment(\.dismiss) var dismiss
    @State var returnToCheckpoint: Bool = false
    var body: some View {
        Section("Checkpoint Actions") {
            Button("Return To Checkpoint Home") {
                navigator.returnToCheckpoint(KnownCheckpoints.home)
            }
            .disabled(!navigator.canReturnToCheckpoint(KnownCheckpoints.home))

            Button("Return To Checkpoint Page 2") {
                returnToCheckpoint = true
            }
            .navigationReturnToCheckpoint(trigger: $returnToCheckpoint, checkpoint: KnownCheckpoints.page2)
            .disabled(!navigator.canReturnToCheckpoint(KnownCheckpoints.page2))

            Button("Return To Checkpoint Duplicate (1, 2)") {
                navigator.returnToCheckpoint(KnownCheckpoints.duplicate)
            }
            .disabled(!navigator.canReturnToCheckpoint(KnownCheckpoints.duplicate))

            Button("Return to Settings Checkpoint Value 9") {
                navigator.returnToCheckpoint(KnownCheckpoints.settings, value: 9)
            }

            Button("Return to Settings w/o Animation") {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    navigator.returnToCheckpoint(KnownCheckpoints.settings, value: 9)
                }
            }

            Button("Return To Unknown Checkpoint") {
                navigator.returnToCheckpoint(KnownCheckpoints.unknown)
            }
        }
    }
}

struct ContentRoutingSection: View {
    @Environment(\.navigator) var navigator
    @Environment(\.homeDependencies) var resolver
    @State var returnToCheckpoint: Bool = false
    var body: some View {
        Section("Routing Actions") {
            Button("Route To Home Page 2, 3") {
                navigator.perform(route: KnownRoutes.homePage2Page3)
            }
            Button("Route To Home Page 2, 3, 99") {
                navigator.perform(route: KnownRoutes.homePage2Page3PageN(99))
            }
            Button("Route To Settings Page 2") {
                try? resolver.homeExternalRouter.route(to: .settingsPage2)
            }
        }
    }
}

struct ContentPopSection: View {
    @Environment(\.navigator) var navigator: Navigator
    @Environment(\.dismiss) var dismiss
    @State var returnToCheckpoint: Bool = false
    var body: some View {
        Section("Pop Actions") {
            Button("Pop Current Screen") {
                navigator.pop()
            }
            .disabled(navigator.isEmpty)

            Button("Pop To 2nd Screen") {
                navigator.pop(to: 1) // count from zero
            }
            .disabled(navigator.isEmpty)

            Button("Pop All Screens") {
                navigator.popAll()
            }
            .disabled(navigator.isEmpty)
         }

        Section("Classic Actions") {
            Button("Go Back") {
                navigator.back()
            }

            Button("Dismiss") {
                dismiss()
            }
        }

    }
}

struct CustomSettingsSheetSection: View {
    @State var showSettings: SettingsDestinations?
    var body: some View {
        Section {
            Button("Present Page 2 via Sheet") {
                showSettings = .page2
            }
            Button("Present Page 3 via Sheet") {
                showSettings = .page3
            }
            .sheet(item: $showSettings) { destination in
                destination
                    .managedPresentationView()
            }
        }
    }
}
