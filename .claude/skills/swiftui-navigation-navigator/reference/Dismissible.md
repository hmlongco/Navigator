# Dismissible (reference)

A **dismissible view** is a *presented* view that **Navigator knows how to dismiss**. Navigator builds a **navigation tree** of such views; that tree enables deep linking, checkpoints, and global dismiss without passing bindings or closures.

## Navigation tree

Navigator builds a tree of **Navigators**:

- **Root**: The application root Navigator (from `.navigationRoot(navigator)`).
- **Children**: Each **ManagedNavigationStack** (e.g. per tab) is a child; each **ManagedPresentationView** (or stack presented via Navigator) is a child of the navigator that presented it.

So: Root → Tab1 stack, Tab2 stack, Tab3 stack → and if Tab3 presents a sheet, that sheet's navigator is a child of Tab3's navigator. The tree can be walked to dismiss from parent or root.

## Four dismiss operations

1. **`navigator.dismiss()`**
   Dismisses the **currently presented** view that *this* Navigator is managing. Use from **inside** that presented view. It does **not** pop the navigation path; it only dismisses the sheet/cover that this navigator presented.

2. **`navigator.dismissPresentedViews()`**
   Dismisses any sheet or fullScreenCover that *this* Navigator presented via `navigate(to:)`. Use from the **parent** that owns this navigator.

3. **`navigator.dismissAnyChildren()`**
   Walks the tree from this Navigator and dismisses every **ManagedNavigationStack** or **ManagedPresentationView** that is a descendant. Use from a **parent** to clear all children. Returns `true` if anything was dismissed.

4. **`navigator.dismissAny()`**
   Goes to the **root** and dismisses *all* presented stacks and presentation views in the entire tree. Used for deep linking (clear everything, then navigate to the target). Returns `true` if anything was dismissed. **Can throw** if navigation is locked (see below).

## Locking navigation

Apply **`.navigationLocked()`** to a view (e.g. a payment sheet). That view can still dismiss itself and its parent can still dismiss it, but **`dismissAny()`** will **throw** and not run. Use when a deep link must not interrupt the user (e.g. mid-transaction). The lock clears when that view is dismissed.

## State-driven modifiers

Dismissal can be triggered by a binding instead of calling the navigator:

- **`.navigationDismiss(trigger: $dismiss)`** — Dismisses the current presented view when the binding becomes true; then resets the binding.
- **`.navigationDismissPresentedViews(trigger: $dismiss)`**
- **`.navigationDismissAnyChildren(trigger: $dismiss)`**
- **`.navigationDismissAny(trigger: $dismiss)`**

Binding must be `Bool`; set to `true` to trigger; it is reset after the action.

## Wrapping custom sheets and covers

If you present a sheet or cover **yourself** (e.g. `.sheet(item: $item) { ... }` or `.fullScreenCover(isPresented:)`) **outside** of `navigate(to:)`, Navigator does not know about that view unless you wrap it. Wrap so the view becomes a node in the tree and can be dismissed by `dismissAny()` / checkpoints:

- **`ManagedPresentationView { MyView() }`** — Wraps content in a view that registers with the parent navigator and gets its own Navigator.
- **`MyView().managedPresentationView()`** — Same as above, modifier style.
- **`ManagedNavigationStack { MyView() }`** — Use when the sheet needs its own navigation stack; it also registers and is dismissible.

Failure to wrap custom presentations can break deep linking and "dismiss any" behavior.

## Checkpoints and dismissible

Returning to a **checkpoint** uses dismissible under the hood: Navigator finds the checkpoint's navigator, calls **dismissAnyChildren()** (or equivalent), then **pop(to: index)**. So checkpoints depend on the tree and dismissible infrastructure. From deep in the tree, prefer **returnToCheckpoint** over manual dismiss so you don't depend on exact stack structure.
