# WidgetForge

Design your own Home Screen widgets from scratch. Lay out text, live clocks and dates,
countdowns, progress rings, SF Symbols, shapes and photos on a canvas, then put the result
on your Home Screen as a real widget.

**New in 2.0:** a Formula layer for small, safe, on-device "coding" of custom text; glowing
backgrounds, dial gauges and frosted glass panels for a Widgy-style look; sharing a design as
a file or as copyable "Design Code"; and generating a design from a short description with
your own Anthropic API key.

## What you can build

- **Three sizes:** Small, Medium, Large.
- **Layers:** Text, Time & Date (presets or any custom pattern), Countdown, Progress
  (ring, bar or dial gauge: today, this week, this month, this year, storage used, battery
  level, or a value you set), SF Symbol, Shape (including a frosted "glass" look), Photo,
  Device (this device's own battery, free storage, uptime or Wi-Fi/cellular status), and
  Formula — a small, safe formula language that combines those values with math and simple
  logic, entirely on your device.
- **Backgrounds:** solid, linear gradient, radial gradient, a glowing blurred-color "aura"
  (the look behind many Widgy-style widgets), or a photo with a darkening slider. Thirteen
  presets to start from.
- **Editor:** drag to move, corner handle to resize, rotate handle, snap-to-center guides,
  undo / redo, a Layers sheet (reorder, hide, lock, delete), duplicate, preview mode.
- **Templates:** Blank, Clock, Countdown, Year Progress, Quote, Photo, Device Stats, Glow
  Clock, Battery Gauge, Glass Card, Big Numerals.
- **Share, import, or generate:** send a design to someone else as a `.widgetforge` file or as
  copyable "Design Code" text, paste in a design someone sent you, hand-edit a design's own
  code, or generate a new one from a short description with your own Anthropic API key. See
  "Share, code, or generate a design" below.
- Changes save automatically and every widget on your Home Screen refreshes.
- Tapping a widget opens its design so you can keep tweaking it.
- A **Credits** page (tap **?**, then **Credits**) lists who made the app: Claude as the main
  developer and VicStinger as the backend and idea developer.

## What you need

- A Mac with **Xcode 15 or newer**, or no Mac at all if you let GitHub build the IPA for you
  (see "Build the IPA on GitHub" below). iOS apps can't be built on Windows or Linux.
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

## Share, code, or generate a design

Every design can leave the app as **"Design Code"** — readable JSON that describes it, with
any photos it uses inlined so the text alone is everything someone else needs to recreate it.
It's the one format behind sharing, hand-editing, and AI generation, so all three understand
each other.

- **Share a design.** From the editor's **…** menu, or a design's context menu in the
  Library, tap **Share…** to send a `.widgetforge` file through AirDrop, Messages, Mail, or
  Files, or **Copy Code** to put its Design Code on the clipboard (to paste into a note, a
  chat, anywhere text goes).
- **Receive one.** Opening a shared `.widgetforge` file (from Files, an AirDrop, or a message
  attachment) opens straight into WidgetForge as a new widget. You can also add one from the
  Library's **+** menu: **Import Design File…** to browse to a file, or **Paste Design
  Code…** to paste text you were sent.
- **Hand-edit the code.** The editor's **…** menu has **View/Edit Code** — the design's own
  JSON, editable in place. **Apply** runs it through the normal edit path, so a mistake is
  never a dead end: fix the text and apply again, or just back out without saving. The
  **？** menu inside that screen has a short field guide to the format.
- **Generate with AI.** The Library's **+** menu has **Generate with AI**: describe what you
  want ("a glowing clock with a day-progress dial") and WidgetForge asks Claude to write the
  Design Code for it, then loads the result as a new widget. This needs your own Anthropic
  API key, free to create at [console.anthropic.com](https://console.anthropic.com/settings/keys).
  The key is stored only on this device, in the Keychain, and every request goes directly
  from your device to Anthropic's API — WidgetForge's authors never see your key or your
  prompts, and nothing about this feature works without a key you supply yourself.

## Build the IPA on GitHub (no Mac needed)

GitHub can build the app for you on one of its Macs. The build needs no Apple account and no
secrets. The workflow lives in `.github/workflows/build-widgetforge-ipa.yml`, and it accepts
the project either as a zip uploaded to the repository root (unzipped automatically during the
build) or as the unzipped project folders pushed directly — so it works whichever way you
uploaded it.

1. Create a new repository on GitHub. Public repositories build for free. On a private one,
   macOS minutes count 10 times against your monthly free allowance.
2. Upload the project to the repository: either the zipped `WidgetForge` folder to the
   **root** of the repository (don't unzip it), or everything **inside** the `WidgetForge`
   folder so that `WidgetForge.xcodeproj` and the `.github` folder sit at the top level. If the
   web uploader skips the hidden `.github` folder, choose **Add file > Create new file**, type
   `.github/workflows/build-widgetforge-ipa.yml` as the name and paste the workflow in.
3. Open the **Actions** tab, choose **Build WidgetForge IPA** and press **Run workflow**. If
   GitHub says a runner wasn't acquired (it happens when Apple-silicon Macs are in short
   supply), run it again and pick **macos-15** or **macos-15-intel** from the *runner* menu
   instead of the default. It takes about 5 to 10 minutes.
4. Open the finished run and download the **WidgetForge-ipa** artifact from the Artifacts
   section at the bottom of the page. It is a zip that contains `WidgetForge.ipa`.
5. If the run fails, open it. The summary lists the compiler errors, and the full log is
   attached as the **build-log** artifact.

**The IPA is not signed for your phone.** iOS only installs signed apps, so re-sign it with a
tool that uses your own Apple ID, such as Sideloadly (Windows or Mac), AltStore or SideStore.
With a free Apple ID the app expires after 7 days, and the widget counts as a second App ID
against Apple's limit of 10 per week. A paid developer account lets you sign it properly.

The workflow ad-hoc signs the IPA with the App Group entitlement so re-signing tools keep it.
Those tools may rename the App Group. The app therefore reads the group iOS actually granted
from its provisioning profile, and the **?** sheet shows which one is in use.

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
- **Device layers** read this device's own battery, storage, uptime and connection — never
  another app's data, which iOS doesn't allow any app to read. Storage, uptime and connection
  are read fresh each time the widget redraws. Battery is the exception: a Home Screen widget
  can't reliably check it itself, so the app reads it whenever you have WidgetForge open and
  saves it to the shared container; the widget shows that saved value, marked "·  _m ago" once
  it's more than 20 minutes old. There's no battery/RAM/CPU "usage" for *other* apps, and no
  live, accurate system-wide RAM or CPU number for this one either — iOS doesn't give
  third-party apps that, so WidgetForge doesn't invent one.
- **Formula layers** (`Shared/FormulaEngine.swift`) run a small hand-written expression
  language — a lexer, a recursive-descent parser, an evaluator — entirely on-device. A formula
  can only read the fixed set of values in `FormulaContext` (battery, date, progress, ...) and
  compute with them; there's no loop, no variable of its own, and no way for it to reach the
  network, the filesystem, or another app, even if the formula came from a design someone else
  shared with you.
- **Design Code** (`Shared/DesignExchange.swift`) is the one format behind sharing, the
  in-app code editor, and AI generation: a design (plus any photos it uses, inlined) encoded
  as JSON. Decoding is tolerant the same way saved designs are, with friendly error messages,
  so a hand-edited typo or a confused AI reply fails gently instead of crashing anything.

## Project layout

```
App/        The app: library, editor, inspector, help, AI generation, code editor. (app target)
Widget/     The widget extension: picker intent, timeline, view.           (extension target)
Shared/     Models, storage, renderer, templates, formula engine, Design Code, AI
            generation's networking.                                       (both targets)
Resources/  Info.plists, entitlements, asset catalog (icon, accent colour).
Config/     WidgetForge.xcconfig: the bundle ID and team settings.
.github/    The GitHub Actions workflow that builds WidgetForge.ipa.
tools/      generate_xcodeproj.py: rebuilds WidgetForge.xcodeproj from the folders.

Resources/PrivacyInfo.xcprivacy declares the two "required reason" API categories a Device
layer uses (checking free storage, reading uptime) to Apple, as Xcode 15+/App Store Connect
require. It only matters if you submit to the App Store; it doesn't affect Xcode, TestFlight
or sideloading. It was written without access to Xcode's own privacy-manifest editor, so
before submitting, open it there (select the file > the editor appears) and confirm the two
reasons it lists still match Apple's current wording — Apple updates the approved list from
time to time.
```

## Troubleshooting

- **Orange "Widgets can't see your designs yet" banner.** The App Group isn't active for this
  build. Check both targets' **Signing & Capabilities** show an *App Groups* entry
  `group.<your APP_BUNDLE_ID>` with a tick, and that both targets use the same Team. For an
  IPA installed with a re-signing tool, the tool has to register the App Group for both the
  app and the widget. If it doesn't, try another tool or sign with Xcode.
- **WidgetForge isn't in the widget gallery.** Run the app once, then try again. On a real
  device it can take a minute to appear.
- **The widget says "Wrong size".** The design you picked was made for a different size.
  Edit the widget and pick one that matches.
- **The widget says "Choose a design".** Nothing of that size exists yet. Create one in the app.
- **A Device layer's battery number looks old, or says "Open WidgetForge once".** That's
  expected: a widget can't check the battery itself, so open the app once (even just to the
  library screen) and the widget will pick up the new reading on its next refresh.
- **Compile errors.** This project was written and statically checked without access to
  Xcode, so it has never been built on a Mac. If Xcode (or the GitHub build) reports an
  error, the message and file name are usually enough to fix it quickly.

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
