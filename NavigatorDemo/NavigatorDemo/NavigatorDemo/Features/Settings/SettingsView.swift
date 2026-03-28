//
//  SettingsView 2.swift
//  Nav5
//
//  Created by Michael Long on 11/18/24.
//

import NavigatorUI
import SwiftUI

class SettingsRootViewModel: ObservableObject {
    @Published var id = UUID()
    init() {
        print(id)
    }
}

struct SettingsRootView: View {
    @EnvironmentObject var rootViewModel: SettingsRootViewModel
    var body: some View {
        ManagedNavigationStack(scene: RootTabs.settings.id) { navigator in
            SettingsView(name: "Root Settings")
                .navigationTitle("Settings")
                .navigationAutoReceive(SettingsDestinations.self)
                .onChange(of: navigator.count) { _, count in
                    print("Count = \(count)")
                }
        }
    }
}

struct SettingsView: View {
    let name: String
    @Environment(\.navigator) var navigator: Navigator
    @State var triggerPage3: Bool = false
    @State var destination: SettingsDestinations?
    @State var returnValue: Int? = nil
    var body: some View {
        List {
            Section("Checkpoint Value Actions") {
                Button("Settings Sheet With Return Value") {
                    navigator.navigate(to: SettingsDestinations.sheet)
                }
                Text("Return Value: \(String(describing: returnValue))")
                    .foregroundStyle(.secondary)
            }

            Section("Navigation Actions") {
                NavigationLink(to: SettingsDestinations.page2) {
                    Text("Link to Settings Page 2!")
                }
                Button("Navigator Push to Settings Page 3!") {
                    navigator.push(SettingsDestinations.page3)
                }
                Button("Modifier Navigate to Settings Page 3!") {
                    triggerPage3.toggle()
                }
                .navigate(trigger: $triggerPage3, destination: SettingsDestinations.page3)
                //                Button("Navigator Push 2, 3 (error)") {
                //                    navigator.push(SettingsDestinations.page2)
                //                    navigator.push(SettingsDestinations.page3)
                //                }
            }

            Section("Unregistered Destination Actions") {
                NavigationLink(to: UnregisteredDestinations.page1) {
                    Text("Link to Unregistered Page 1!")
                }
                Button("Button Push to Unregistered Page 2!") {
                    navigator.navigate(to: UnregisteredDestinations.page2)
                }
                Button("Button Present Unregistered Page 2!") {
                    navigator.navigate(to: UnregisteredDestinations.page2, method: .sheet)
                }
            }

            Section("Send Actions") {
                Button("Send Page 2 via Navigator") {
                    navigator.send(SettingsDestinations.page2)
                }
                Button("Send Page 3 via Modifier") {
                    destination = SettingsDestinations.page3
                }
                .navigationSend($destination)
                Button("Send Tab Home, Page 2, 88, Present") {
                    // assumes knowledge of app structure, doing a route would be better
                    navigator.send(
                        NavigationAction.dismissAny,
                        RootTabs.home,
                        NavigationAction.popAll(in: RootTabs.home.id),
                        HomeDestinations.page2,
                        HomeDestinations.pageN(88),
                        HomeDestinations.presented1
                    )
                }
            }

            Section("Resume Actions") {
                Button("Present Resumable Loading View") {
                    navigator.send(
                        SettingsDestinations.presentLoading,
                        LoadingDestinations.external
                    )
                }

            }
        }
        .navigationTitle(name)
        // establishes a standard checkpoint
        .navigationCheckpoint(KnownCheckpoints.settings)
        // establishes a checkpoint with a return value handler
        .navigationCheckpoint(KnownCheckpoints.settings) { result in
            returnValue = result
        }
    }
}

struct Page2SettingsView: View {
    @Environment(\.navigator) var navigator: Navigator
    @State var returnValue: Int? = nil
    var body: some View {
        List {
            Section("Checkpoint Value Actions") {
                Button("Settings Sheet With Return Value") {
                    navigator.navigate(to: SettingsDestinations.sheet)
                }
                Text("Return Value: \(String(describing: returnValue))")
                    .foregroundStyle(.secondary)
            }
            Section("Navigation Actions") {
                NavigationLink(to: SettingsDestinations.page3) {
                    Text("Link to Test Page 3!")
                }
            }
            CustomSettingsSheetSection()
            ContentCheckpointSection()
            ContentPopSection()
        }
        .navigationCheckpoint(KnownCheckpoints.page2)
        // establishes a second checkpoint with a return value handler
        .navigationCheckpoint(KnownCheckpoints.settings) { result in
            returnValue = result
        }
        .navigationTitle("Page 2")
    }
}

struct Page3SettingsView: View {
    var body: some View {
        List {
            ContentCheckpointSection()
            ContentPopSection()
        }
        .navigationTitle("Page 3")
    }
}

struct SettingsSheetView: View {
    @Environment(\.navigator) var navigator: Navigator
    var body: some View {
        List {
            Section("Checkpoint Actions") {
                Button("Return to Settings Checkpoint Value 5") {
                    navigator.returnToCheckpoint(KnownCheckpoints.settings, value: 5)
                }
                Button("Return to Settings Checkpoint Value 0") {
                    navigator.returnToCheckpoint(KnownCheckpoints.settings, value: 0)
                }
                // Button("Return to Missing Settings Handler 0.0") {
                // Cannot convert value of type 'Double' to expected argument type 'Int'
                // navigator.returnToCheckpoint(KnownCheckpoints.settings, value: 0.0)
                // }
            }
            Section("Send Actions") {
                Button("Send Tab Home") {
                    navigator.send(
                        NavigationAction.dismissAny,
                        RootTabs.home
                    )
                }
            }
            ContentSheetSection()
        }
        .navigationTitle("Sheet")
    }
}

struct SettingsExternalView: View {
    @Environment(\.navigator) var navigator: Navigator
    var body: some View {
        List {
            Text("External View")
        }
        .navigationTitle("External View")
    }
}

struct PresentLoadingView: View {
    @State var loading: Bool = true
    var body: some View {
        ManagedNavigationStack {
            List {
                if loading {
                    Text("Loading...")
                        .task {
                            try? await Task.sleep(for: .seconds(3))
                            self.loading = false
                        }
                } else {
                    Text("Loaded...")
                        .navigationResume() // resume when this view appears
                }
            }
            .navigationAutoReceive(LoadingDestinations.self)
            .navigationTitle("Presented View")
        }
    }
}
