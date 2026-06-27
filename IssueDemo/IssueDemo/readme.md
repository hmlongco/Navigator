# Issue

Routing doesn't respect the navigation method properly.

## Version

- Navigator v1.3.1
- iPhone simulator 17 Pro with iOS 26

## To reproduce the issue

1. Run the app to reach Screen A.
2. Press "Navigate to ScreenB", this present Screen B modally as a sheet.
3. Press "Route to Screen C", this routes to Screen C which will dismiss Screen B and then pressent Screen C.

## Current behavior

Screen C is presented, but as a sheet, not as a full-screen cover.

## Expected behavior

Screen C is presented, but should be a full-screen cover, because that's what is defined in `ScreenADestinations.method`.

## Notes

The console prints:

```
Setting modalPresentationStyle once presentationController has been accessed will have no effect until <_TtGC7SwiftUI29PresentationHostingControllerVS_7AnyView_: 0x1068b9e00> is presented, dismissed, and presented again.
```

This issue only happens when using a `TabView` AND setting `.preferredColorScheme` on Screen B AND presenting Screen B as a full-screen cover.

If no `TabView` is involved (just set `useTabsView` to `false` in `IssueDemoApp`) then this issue is not visible.

If `.preferredColorScheme` on Screen B is removed or the parameter is nil then the issue is not visible. For the other screens involved it doesn't matter if this view modifier is used on them or not, only for Screen B it matters for this issue.

If the navigation method in ScreenADestinations for `screenB` is changed from `managedSheet` to `managedCover` then this also solves the issue.
