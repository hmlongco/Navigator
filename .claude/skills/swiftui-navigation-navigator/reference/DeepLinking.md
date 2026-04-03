# Deep linking (reference)

Navigator supports **deep linking** and **in-app routing** via **navigation send**: you broadcast an ordered list of **Hashable** values, and typed receivers in the tree handle each value (e.g. switch tab, then push a destination). The same mechanism can be abstracted behind **routes** so URL handlers and in-app buttons share one implementation.

## Send: ordered delivery

**`navigator.send(values: [value1, value2, ...])`** (or variadic **`navigator.send(value1, value2, ...)`**) delivers values **one at a time** to the tree. Each value is matched by **type** to a receiver; only one receiver should consume each value for a given type. Receivers run in tree order; the first matching receiver gets the value.

Example: to deep link to Settings → Profile → Photo sheet, send:

```swift
navigator.send(
    RootTabs.settings,
    SettingsDestinations.profile,
    SettingsDestinations.photo
)
```

A receiver for `RootTabs` updates the selected tab; a receiver for `SettingsDestinations` (inside the Settings stack) calls `navigator.navigate(to: destination)`. Navigator handles ordering and timing (e.g. delay between steps so the UI can update).

## Receive and resume

- **`.onNavigationReceive { (value: SomeType) in ... return .auto }`** — The handler receives values of type `SomeType`. Return a **NavigationReceiveResumeType** to control what happens next:
  - **`.auto`** — Continue with the next value after a short delay.
  - **`.immediately`** — Continue immediately.
  - **`.pause`** — Pause the queue (e.g. for auth); resume later with **`navigator.resume()`** or **`.navigationResume()`**.
  - **`.cancel`** — Stop processing the rest.
  - **`.after(TimeInterval)`** — Continue after a delay.
  - **`.inserting([values])`** / **`.appending([values])`** / **`.replacing([values])`** — Modify the remaining queue.

- **`.onNavigationReceive(assign: $selectedTab)`** — Shortcut when you only need to set a binding and continue (e.g. tab selection). Equivalent to a handler that sets the binding and returns `.auto` or `.immediately` as appropriate.

- **`.onNavigationReceive { (dest: HomeDestinations, navigator) in navigator.navigate(to: dest); return .auto }`** — For destinations, navigate and continue. Shortcut: **`.navigationAutoReceive(HomeDestinations.self)`** does the same for that type.

Only **one** receiver per type should consume a value; duplicate receivers for the same type can lead to warnings and ignored handlers.

## Routes vs destinations

- **Destination** — A single screen: one Navigator pushes or presents one view (one value).
- **Route** — A high-level "place" in the app (e.g. "edit profile photo") that may require a **sequence** of actions: switch tab, push profile, present photo. A route is implemented by sending that sequence.

Define **routes** as an enum conforming to **NavigationRoutes** (e.g. `enum KnownRoutes: NavigationRoutes`). Implement **NavigationRouteHandling** with a type that maps each route to a **send** sequence. Install with **`.onNavigationRoute(YourRouter())`**. Trigger with **`navigator.perform(route: KnownRoutes.profilePhoto)`**. The button (or URL handler) only knows the route; the router knows the sequence. Use the **same** router for deep links and in-app navigation so URL parsing just calls **`perform(route:)`**.

## Separation of concerns

- **URL parser** — Maps URL to a route (e.g. `KnownRoutes.profilePhoto`). Does not know app structure.
- **Route handler** — Maps route to `navigator.send(values: [...])`. Knows structure but not view types.
- **Receivers** — Update local state or navigate. Each knows only its own type.

Optional: use **onNavigationOpenURL** (or equivalent) to register URL handlers that parse the URL and call **`navigator.perform(route: ...)`**, so deep links and in-app routing share the same route handler.
