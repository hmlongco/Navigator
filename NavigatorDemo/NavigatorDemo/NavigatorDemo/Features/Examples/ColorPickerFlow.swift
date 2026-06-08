//
//  ColorPickerFlow.swift
//  Navigator
//
//  Created by Michael Long on 2/12/25.
//

import NavigatorUI
import SwiftUI

/// A typed flow demonstrating value-returning completion.
///
/// Anchored to `FlowCheckpoints.pickedColor` (a `NavigationCheckpoint<Color>`)
/// via `navigator.start(_:returningTo:)`. Completion routes the picked color
/// to the checkpoint's handler.
nonisolated struct ColorPickerFlow: NavigationFlow {

    typealias Value = Color

    var checkpoint: NavigationFlowCheckpoint<Color>?

    nonisolated enum Destination: NavigationDestination {
        case picker(ColorPickerFlow)

        var body: some View {
            switch self {
            case .picker(let flow):
                ColorPickerView(flow)
            }
        }

        var method: NavigationMethod {
            .managedSheet
        }
    }

    func start() -> FlowResult<Self> {
        .destination(.picker(self))
    }

    func next() async throws -> FlowResult<Self> {
        // Not used in this single-step flow. A multi-step typed flow would
        // return `.completeWithValue(value, self)` from here to terminate
        // programmatically with a value.
        .complete(self)
    }
}

struct ColorPickerView: View {
    @Environment(\.navigator) private var navigator
    let flow: ColorPickerFlow

    init(_ flow: ColorPickerFlow) {
        self.flow = flow
    }

    private let choices: [(name: String, color: Color)] = [
        ("Red", .red), ("Green", .green), ("Blue", .blue)
    ]

    var body: some View {
        Form {
            Section("Pick a color to return") {
                ForEach(choices, id: \.name) { entry in
                    Button(entry.name) {
                        navigator.complete(flow, returning: entry.color)
                    }
                    .foregroundStyle(entry.color)
                }
            }
            Section {
                Button("Cancel") {
                    navigator.cancel(flow)
                }
            }
        }
        .navigationTitle("Color Picker")
        .navigationBarTitleDisplayMode(.inline)
    }
}
