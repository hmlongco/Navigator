//
//  FlowExampleView.swift
//  Navigator
//
//  Created by Michael Long on 2/12/25.
//

import NavigatorUI
import SwiftUI

struct FlowExampleView: View {
    @State private var onboardedName: String?
    @State private var pickedColor: Color?

    var body: some View {
        ManagedNavigationStack { navigator in
            List {
                Section("Navigation Flows") {
                    Button {
                        navigator.start(OnboardingFlow(), returningTo: FlowCheckpoints.onboarded)
                    } label: {
                        HStack {
                            Text("Start Onboarding Flow")
                            Spacer()
                            if let onboardedName {
                                Text(onboardedName)
                            }
                        }
                    }

                    Button {
                        navigator.start(ColorPickerFlow(), returningTo: FlowCheckpoints.pickedColor)
                    } label: {
                        HStack {
                            Text("Start Color Picker Flow")
                            Spacer()
                            if let pickedColor {
                                Circle()
                                    .fill(pickedColor)
                                    .frame(width: 20, height: 20)
                            }
                        }
                    }

                    Button("Start 1-2-3 Flow") {
                        navigator.start(CounterFlow())
                    }
                }

                Section {
                    Button("Dismiss Example") {
                        navigator.dismiss()
                    }
                }
            }
            .navigationCheckpoint(FlowCheckpoints.onboarded) { name in
                onboardedName = name
            }
            .navigationCheckpoint(FlowCheckpoints.pickedColor) { color in
                pickedColor = color
            }
            .navigationTitle("Flow Examples")
        }
    }
}

struct FlowCheckpoints: NavigationCheckpoints {
    public static var onboarded: NavigationCheckpoint<String> { checkpoint() }
    public static var pickedColor: NavigationCheckpoint<Color> { checkpoint() }
}
