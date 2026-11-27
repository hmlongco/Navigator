//
//  NavigationSceneStorage.swift
//  Navigator
//
//  Created by Michael Long on 11/24/24.
//

import SwiftUI

/// Provides state restoration storage for named ManagedNavigationControllers.
nonisolated internal struct NavigationSceneStorage: Codable {

    let name: String?
    let restorationKey: String
    let path: Data?
    let checkpoints: [String: AnyNavigationCheckpoint]
    let dismissible: Bool
    let sheet: Data?
    let cover: Data?

    internal init(
        name: String?,
        restorationKey: String,
        path: Data?,
        checkpoints: [String : AnyNavigationCheckpoint] = [:],
        dismissible: Bool = false,
        sheet: Data?,
        cover: Data?
    ) {
        self.name = name
        self.restorationKey = restorationKey
        self.path = path
        self.checkpoints = checkpoints
        self.dismissible = dismissible
        self.sheet = sheet
        self.cover = cover
    }

}

extension Navigator {

    internal static let decoder = JSONDecoder()
    internal static let encoder = JSONEncoder()

    /// Encoding for scene storage
    internal func encoded() -> Data? {
        guard let restorationKey = configuration?.restorationKey else {
            return nil
        }
        let path = try? path.codable.map(Navigator.encoder.encode)
        let storage = NavigationSceneStorage(
            name: name,
            restorationKey: restorationKey,
            path: path ?? Data(),
            checkpoints: checkpoints,
            dismissible: isPresented,
            sheet: try? Navigator.encoder.encode(sheet),
            cover: try? Navigator.encoder.encode(cover)
        )
        return try? Navigator.encoder.encode(storage)
    }

    /// Decoding from scene storage
    internal func restore(from data: Data) {
        guard let storage = try? Navigator.decoder.decode(NavigationSceneStorage.self, from: data),
              storage.restorationKey == configuration?.restorationKey else {
            return
        }
        self.name = storage.name
        if let data = storage.path, let representation = try? Navigator.decoder.decode(NavigationPath.CodableRepresentation.self, from: data) {
            path = NavigationPath(representation)
        } else {
            path = .init()
        }
        // merge checkpoint indices only
        for (key, stored) in storage.checkpoints {
            if let checkpoint = checkpoints[key]?.setting(index: stored.index) {
                checkpoints[key] = checkpoint
            }
        }
        if let data = storage.sheet {
            sheet = try? Navigator.decoder.decode(AnyNavigationDestination.self, from: data)
        } else {
            sheet = nil
        }
        if let data = storage.cover {
            cover = try? Navigator.decoder.decode(AnyNavigationDestination.self, from: data)
        } else {
            cover = nil
        }
    }

}

internal struct NavigationSceneStorageModifier: ViewModifier {

    internal var navigator: Navigator
    internal var name: String? = nil

    func body(content: Content) -> some View {
        if let name, navigator.configuration?.restorationKey != nil {
            content.modifier(EnabledNavigationSceneStorageModifier(navigator: navigator, name: name))
        } else {
            content
        }
    }

}

private struct EnabledNavigationSceneStorageModifier: ViewModifier {

    var navigator: Navigator

    @Environment(\.scenePhase) private var scenePhase
    @SceneStorage private var sceneStorage: Data?

    init(navigator: Navigator, name: String) {
        self.navigator = navigator
        self._sceneStorage = SceneStorage("NavigationSceneStorage.\(name)")
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) { _, phase in
                if phase == .active, let data = sceneStorage {
                    navigator.restore(from: data)
                } else {
                    sceneStorage = navigator.encoded()
                }
            }
    }

}
