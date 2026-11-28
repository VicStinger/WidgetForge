import SwiftUI

@main
struct WidgetForgeApp: App {
    @StateObject private var library = DesignLibrary()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            DesignLibraryView()
                .environmentObject(library)
                .onOpenURL { url in
                    library.handle(url: url)
                }
                .onAppear {
                    // A Home Screen widget can't reliably read the battery itself, so the app
                    // caches the level here whenever it's open for the widget to show later.
                    DeviceStats.refreshBatterySnapshot()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                DeviceStats.refreshBatterySnapshot()
            }
        }
    }
}
