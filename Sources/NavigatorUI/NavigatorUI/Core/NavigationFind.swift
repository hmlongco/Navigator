//
//  NavigationFind.swift
//  Navigator
//
//  Created by Michael Long on 1/18/25.
//

import SwiftUI

extension Navigator {

    /// Returns first navigator found with given id
    @MainActor public func find(id: UUID) -> Navigator? {
        root.recursiveFindChild { $0.id == id }
    }

    /// Returns first navigator found with given name
    @MainActor public func named(_ name: String) -> Navigator? {
        root.recursiveFindChild { $0.name == name }
    }

    /// Returns child navigator found with given name
    @MainActor public func child(named name: String) -> Navigator? {
        recursiveFindChild { $0.name == name }
    }

    /// Find a parent navigator that matches the current condition
    internal func recursiveFindParent(_ condition: (Navigator) -> Bool) -> Navigator? {
        if let parent = parent {
            if condition(parent) {
                return parent
            } else {
                return parent.recursiveFindParent(condition)
            }
        }
        return nil
    }

    /// Finds a child navigator that matches the current condition starting from the current node
    internal func recursiveFindChild(_ condition: (Navigator) -> Bool) -> Navigator? {
        if condition(self) {
            return self
        }
        for child in _children.values {
            if let navigator = child.object, let found = navigator.recursiveFindChild(condition) {
                return found
            }
        }
        return nil
    }

}
