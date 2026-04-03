# Checkpoints (reference)

**Checkpoints** are named points in the navigation tree to which you can return without knowing the exact stack structure or passing bindings. They avoid fragile chains of `pop()` and `dismiss()` and support the coordinator pattern: views agree on a **name**, not on who holds state.

## Why checkpoints

- **pop()** and **dismiss()** assume the caller knows how many levels to pop or which presented view to dismiss. That couples code to the app's structure.
- Passing **bindings or callbacks** down the tree works but is cumbersome and hard to maintain.
- **Checkpoints** let any view say "return to the place named X"; Navigator finds that place in the tree and dismisses/pops back to it. The caller does not need to know if they were pushed or presented.

## Defining a checkpoint

1. Conform a type to **NavigationCheckpoints** (marker protocol).
2. Add static computed properties that return **`NavigationCheckpoint<Void>`** or **`NavigationCheckpoint<T>`** using **`checkpoint()`**.
3. Use **`{ checkpoint() }`** (computed), not `= checkpoint()`, so each use gets a stable, unique name derived from the property.

```swift
struct KnownCheckpoints: NavigationCheckpoints {
    static var home: NavigationCheckpoint<Void> { checkpoint() }
    static var page2: NavigationCheckpoint<Void> { checkpoint() }
    static var settings: NavigationCheckpoint<Int> { checkpoint() }  // value return
}
```

## Establishing a checkpoint

Attach the checkpoint to the **view that is** that place in the tree (e.g. the root of a stack):

```swift
ManagedNavigationStack(scene: "home") {
    HomeContentView(title: "Home Navigation")
        .navigationCheckpoint(KnownCheckpoints.home)
}
```

That view is now the named target for "return to home."

## Returning to a checkpoint

- **`navigator.returnToCheckpoint(KnownCheckpoints.home)`** — Dismisses any presented views and pops back to the view that has `.navigationCheckpoint(KnownCheckpoints.home)`.
- **`navigator.canReturnToCheckpoint(KnownCheckpoints.home)`** — Use to enable/disable a "return" button (e.g. `.disabled(!navigator.canReturnToCheckpoint(KnownCheckpoints.home))`).

Return can be **state-driven**: **`.navigationReturnToCheckpoint(trigger: $returnToHome, checkpoint: KnownCheckpoints.home)`**. When the binding becomes true, Navigator performs the return and resets the trigger.

## Returning a value to a checkpoint

When the checkpoint has a **value type** (e.g. `NavigationCheckpoint<Int>`):

1. **Establish** with a handler: **`.navigationCheckpoint(KnownCheckpoints.settings) { result in returnValue = result }`**
2. **Return** with a value: **`navigator.returnToCheckpoint(KnownCheckpoints.settings, value: 5)`**

The type in the handler and the type passed to `returnToCheckpoint(_:value:)` must match, or the handler will not be called. Value-returning checkpoints are useful for state restoration and callbacks that must survive persistence (bindings and closures cannot be persisted).

## State restoration

Checkpoints work well with **state restoration** because they are identified by name and (optionally) value type, not by closures or bindings. When restoring navigation state, checkpoints can be re-established and returned to by name.

## Coordinator pattern

Views that want to "go back to home" (or any named place) only need to know the checkpoint name. They do not need to know whether they were pushed or presented, or how deep they are. That separation is the coordinator-style benefit of checkpoints.
