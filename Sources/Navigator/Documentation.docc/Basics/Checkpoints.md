# Checkpoints

Navigation Checkpoints allow one to return to a specific waypoint in the navigation tree.

## Overview

Like most systems based on NavigationStack, Navigator supports operations like popping back to a previous view, dismissing a presented view, and so on.
```swift
Button("Pop To Previous Screen") {
    navigator.pop()
}
Button("Dismiss Presented View") {
    navigator.dismiss()
}
```
But those are all imperative operations. While one can programmatically pop and dismiss their way out of a screen, that approach is problematic and tends to be fragile. It also assumes that the code has explicit knowledge of the application structure and navigation tree.

One could pass bindings down the tree, but that can also be cumbersome and difficult to maintain.

Fortunately, Navigator supports checkpoints; named points in the navigation stack to which one can easily return.

## Examples

### Defining a Checkpoint
Checkpoints are easy to define and use. Let's create one called "home".
```swift
extension NavigationCheckpoint {
    public static let home: NavigationCheckpoint = "myApp.home"
}
```

### Establishing a Checkpoint
Now lets attach that checkpoint to our home view.
```swift
struct RootHomeView: View {
    var body: some View {
        ManagedNavigationStack(scene: "home") {
            HomeContentView(title: "Home Navigation")
                .navigationCheckpoint(.home)
                .navigationDestination(HomeDestinations.self)
        }
    }
}
```

### Returning to a Checkpoint
Once defined, they're easy to use.
```swift
Button("Return To Checkpoint Home") {
    navigator.returnToCheckpoint(.home)
}
.disabled(!navigator.canReturnToCheckpoint(.home))
```
When fired, checkpoints will dismiss any presented screens and pop any pushed views to return exactly where desired.

## Advanced Checkpoints

### Returning values to a Checkpoint
Checkpoints can also be used to return values to a caller.

As before we establish our checkpoint, but this time we add a handler that receives a specific value type.
```swift
// Define a checkpoint with a value handler.
.navigationCheckpoint(.settings) { (result: Int) in
    returnValue = result
}
```
And then later on when we're ready to return we call `returnToCheckpoint` as usual, but in this case passing our return value as well. 
```swift
// Return, passing a value.
Button("Return to Settings Checkpoint Passing Value 5") {
    navigator.returnToCheckpoint(.settings, value: 5)
}
```
This comes in handy when enabling state restoration in our navigation system, especially since view bindings and callback closures can't be persisted to external storage.

> Important: The value types specified in the handler and sent by the return function must match. If they don't then the handler will not be called.

Checkpoints are a powerful tool. Use them.
