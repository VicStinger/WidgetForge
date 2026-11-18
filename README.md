#More vibecoded stuff
# WidgetForge

Design your own Home Screen widgets from scratch. Lay out text, live clocks and dates,
countdowns, progress rings, SF Symbols, shapes and photos on a canvas, then put the result
on your Home Screen as a real widget.

## What you can build

- **Three sizes:** Small, Medium, Large.
- **Layers:** Text, Time & Date (presets or any custom pattern), Countdown, Progress
  (ring or bar: today, this week, this month, this year, or a value you set), SF Symbol,
  Shape, Photo.
- **Backgrounds:** solid, linear gradient, radial gradient or a photo with a darkening slider.
  Ten presets to start from.
- **Editor:** drag to move, corner handle to resize, rotate handle, snap-to-center guides,
  undo / redo, a Layers sheet (reorder, hide, lock, delete), duplicate, preview mode.
- **Templates:** Blank, Clock, Countdown, Year Progress, Quote, Photo.
- Changes save automatically and every widget on your Home Screen refreshes.
- Tapping a widget opens its design so you can keep tweaking it.

## What you need

- A Mac with **Xcode 15 or newer**. iOS apps can't be built on Windows or Linux.
- An iPhone or iPad on **iOS 17 or later**, or the Xcode iOS Simulator.
- A free Apple ID is enough to run on your own device (the app has to be reinstalled every
  7 days). A paid developer account removes that limit.

## Run it

1. Unzip and double-click `WidgetForge.xcodeproj`.
2. Click the **WidgetForge** project at the top of the file list. For **each of the two
   targets** (*WidgetForge* and *WidgetForgeExtension*) open **Signing & Capabilities** and
   choose your **Team**. (Add your Apple ID first under Xcode > Settings > Accounts.)
3. If Xcode says the bundle identifier isn't available, open `Config/WidgetForge.xcconfig`
   and change `APP_BUNDLE_ID` to something unique to you, for example
   `com.yourname.WidgetForge`. That one value also sets the widget's identifier and the
   shared App Group, so there is nothing else to edit.
4. Pick your iPhone (or a Simulator) in the toolbar and press **Run**.
   On a real device you may first need to turn on **Developer Mode** (Settings > Privacy &
   Security) and trust your certificate (Settings > General > VPN & Device Management).

## Put a widget on the Home Screen

1. In WidgetForge tap **+**, choose a size and a starting point, tap **Create**, and design it.
2. On the Home Screen touch and hold an empty spot, tap **+**, search for **WidgetForge**,
   pick the same size as your design, then **Add Widget**.
3. Touch and hold the new widget, choose **Edit Widget**, and pick your design.
   If you skip this step the widget shows your newest design of that size.

The in-app **?** button repeats these steps and shows whether widgets can reach your designs.

## How it works

WidgetKit can't create new kinds of widget at runtime, so the extension ships one
configurable widget. Each widget you place chooses one of your saved designs (an App Intent
powers the *Edit Widget* picker) and draws it.

- **Designs** are small JSON files in an App Group container shared by the app and the
  extension. Photos are downsized JPEGs in the same container.
- **One renderer** (`Shared/DesignRenderer.swift`) draws both the editor canvas and the
  widget, so what you see in the editor is what you get on the Home Screen.
- **Live content** is scheduled by `Shared/RefreshPlanner.swift`: clocks get one timeline
  entry per minute, day progress one every 15 minutes, everything else updates at midnight.
  iOS decides when widgets actually redraw, so a clock can lag by a minute or two.

## Project layout

```
App/        The app: library, editor, inspector, help.            (app target)
Widget/     The widget extension: picker intent, timeline, view.  (extension target)
Shared/     Models, storage, renderer, templates.                 (both targets)
Resources/  Info.plists, entitlements, asset catalog (icon, accent colour).
Config/     WidgetForge.xcconfig: the bundle ID and team settings.
tools/      generate_xcodeproj.py: rebuilds WidgetForge.xcodeproj from the folders.
```

## Troubleshooting

- **Orange "Widgets can't see your designs yet" banner.** The App Group isn't active for this
  build. Check both targets' **Signing & Capabilities** show an *App Groups* entry
  `group.<your APP_BUNDLE_ID>` with a tick, and that both targets use the same Team.
- **WidgetForge isn't in the widget gallery.** Run the app once, then try again. On a real
  device it can take a minute to appear.
- **The widget says "Wrong size".** The design you picked was made for a different size.
  Edit the widget and pick one that matches.
- **The widget says "Choose a design".** Nothing of that size exists yet. Create one in the app.
- **Compile errors.** This project was written and statically checked without access to
  Xcode, so it has never been built on a Mac. If Xcode reports an error, the message and
  file name are usually enough to fix it quickly.

## Changing the code

- To add a property to a layer, add it to `DesignElement` in `Shared/Models.swift` and to
  its `CodingKeys` and `init(from:)`. Every property is decoded with a fallback, so designs
  saved by an older version keep loading.
- After adding or removing Swift files outside Xcode, run
  `python3 tools/generate_xcodeproj.py` to rebuild the project file (standard library only).
- The code uses iOS 17 APIs (interactive-widget era `AppIntentConfiguration`,
  `containerBackground`, `ContentUnavailableView`), so the minimum is iOS 17.

## Not included (yet)

Lock Screen widgets, weather or calendar data (they need extra permissions), and
interactive controls inside widgets.

