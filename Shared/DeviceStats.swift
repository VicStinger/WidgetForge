import Foundation
#if canImport(UIKit)
import UIKit
#endif
import SystemConfiguration

// MARK: - Battery snapshot

/// The last battery reading the WidgetForge app saw, cached in the App Group container so a
/// Home Screen widget — which can't reliably read the battery itself — can still show a
/// recent value instead of nothing.
private struct BatterySnapshot: Codable {
    var percent: Int
    var isCharging: Bool
    var capturedAt: Date
}

private enum BatterySnapshotStore {
    private static var fileURL: URL {
        DesignStorage.rootURL.appendingPathComponent("battery.json")
    }

    static func save(percent: Int, isCharging: Bool) {
        let snapshot = BatterySnapshot(percent: percent, isCharging: isCharging, capturedAt: Date())
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func load() -> BatterySnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(BatterySnapshot.self, from: data)
    }
}

// MARK: - Device facts

/// Facts about this device, and only this device, that a Device layer can show. Nothing here
/// reads another app — iOS doesn't let any app do that, on purpose.
///
/// There's no "RAM used" or "CPU usage" here: iOS doesn't give third-party apps a reliable,
/// accurate reading of either for the whole device (only an app's own tiny slice of both),
/// so showing a number for them would mean making one up. `deviceInfo` shows the device's
/// name and iOS version instead, which is real and accurate.
enum DeviceStats {
    static func text(for kind: DeviceStatKind) -> String {
        switch kind {
        case .battery: return batteryText()
        case .storage: return storageText()
        case .uptime: return uptimeText()
        case .network: return networkText()
        case .deviceInfo: return deviceInfoText()
        }
    }

    // MARK: Battery
    //
    // UIDevice's battery level is only meaningful in the process that turned monitoring on,
    // which the app does below. A widget extension never calls that, so its own read of
    // batteryLevel comes back -1 ("unknown") and it falls back to the app's cached snapshot.

    #if canImport(UIKit)
    /// Call when the app launches or comes to the foreground, so the widget has a recent
    /// reading to fall back to.
    static func refreshBatterySnapshot() {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        guard device.batteryLevel >= 0 else { return }
        let percent = Int((device.batteryLevel * 100).rounded())
        let isCharging = device.batteryState == .charging || device.batteryState == .full
        BatterySnapshotStore.save(percent: percent, isCharging: isCharging)
    }
    #endif

    private static func batteryText() -> String {
        #if canImport(UIKit)
        let device = UIDevice.current
        if device.batteryLevel >= 0 {
            let percent = Int((device.batteryLevel * 100).rounded())
            let isCharging = device.batteryState == .charging || device.batteryState == .full
            return formattedBattery(percent: percent, isCharging: isCharging, ageMinutes: nil)
        }
        #endif
        guard let snapshot = BatterySnapshotStore.load() else { return "Open WidgetForge once" }
        let minutes = max(0, Int(Date().timeIntervalSince(snapshot.capturedAt) / 60))
        return formattedBattery(percent: snapshot.percent, isCharging: snapshot.isCharging, ageMinutes: minutes)
    }

    private static func formattedBattery(percent: Int, isCharging: Bool, ageMinutes: Int?) -> String {
        var text = "\(percent)%"
        if isCharging { text += " ⚡" }
        if let ageMinutes, ageMinutes >= 20 {
            text += ageMinutes < 60 ? " · \(ageMinutes)m ago" : " · \(ageMinutes / 60)h ago"
        }
        return text
    }

    // MARK: Storage
    // Free and total space on the device's one data volume. Unlike battery, this can be read
    // directly in the widget too, so there's nothing to cache.

    /// 0...1 fraction used, for a Progress layer with source "Storage used".
    static func storageUsedFraction() -> Double {
        guard let (free, total) = storageBytes(), total > 0 else { return 0 }
        return min(max(1 - (Double(free) / Double(total)), 0), 1)
    }

    private static func storageText() -> String {
        guard let (free, total) = storageBytes() else { return "Unknown" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useGB, .useMB]
        return "\(formatter.string(fromByteCount: free)) free of \(formatter.string(fromByteCount: total))"
    }

    private static func storageBytes() -> (free: Int64, total: Int64)? {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        guard let values = try? url.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey
        ]) else { return nil }
        guard let free = values.volumeAvailableCapacityForImportantUsage,
              let total = values.volumeTotalCapacity else { return nil }
        return (free, Int64(total))
    }

    // MARK: Uptime

    private static func uptimeText() -> String {
        let seconds = Int(ProcessInfo.processInfo.systemUptime)
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60
        if days > 0 { return "Up \(days)d \(hours)h" }
        if hours > 0 { return "Up \(hours)h \(minutes)m" }
        return "Up \(minutes)m"
    }

    // MARK: Network
    //
    // SCNetworkReachability, not the newer Network framework, because it can be read
    // synchronously — this code runs inside a SwiftUI view body, with no good place to await
    // an async result.

    private static func networkText() -> String {
        var zero = sockaddr()
        zero.sa_len = UInt8(MemoryLayout<sockaddr>.size)
        zero.sa_family = sa_family_t(AF_INET)
        guard let reachability = SCNetworkReachabilityCreateWithAddress(nil, &zero) else { return "Unknown" }
        var flags = SCNetworkReachabilityFlags()
        guard SCNetworkReachabilityGetFlags(reachability, &flags) else { return "Unknown" }
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        guard isReachable, !needsConnection else { return "Offline" }
        #if canImport(UIKit)
        if flags.contains(.isWWAN) { return "Cellular" }
        #endif
        return "Wi-Fi"
    }

    // MARK: Device info

    private static func deviceInfoText() -> String {
        #if canImport(UIKit)
        let device = UIDevice.current
        return "\(device.name) · \(device.systemName) \(device.systemVersion)"
        #else
        return "This device"
        #endif
    }

    // MARK: Raw values, for the Formula layer
    //
    // Same facts as above, as plain numbers instead of formatted strings, so a formula can do
    // its own arithmetic and comparisons with them.

    /// The battery percent and charging state used by formulas: a live reading in the app, the
    /// cached snapshot (silently, with no age shown) in a widget.
    static func batteryRaw() -> (percent: Int, isCharging: Bool) {
        #if canImport(UIKit)
        let device = UIDevice.current
        if device.batteryLevel >= 0 {
            let percent = Int((device.batteryLevel * 100).rounded())
            let isCharging = device.batteryState == .charging || device.batteryState == .full
            return (percent, isCharging)
        }
        #endif
        guard let snapshot = BatterySnapshotStore.load() else { return (0, false) }
        return (snapshot.percent, snapshot.isCharging)
    }

    static func storageFreeGB() -> Double {
        guard let (free, _) = storageBytes() else { return 0 }
        return Double(free) / 1_000_000_000
    }

    static func uptimeSeconds() -> Double {
        ProcessInfo.processInfo.systemUptime
    }

    static func isOnline() -> Bool {
        var zero = sockaddr()
        zero.sa_len = UInt8(MemoryLayout<sockaddr>.size)
        zero.sa_family = sa_family_t(AF_INET)
        guard let reachability = SCNetworkReachabilityCreateWithAddress(nil, &zero) else { return false }
        var flags = SCNetworkReachabilityFlags()
        guard SCNetworkReachabilityGetFlags(reachability, &flags) else { return false }
        return flags.contains(.reachable) && !flags.contains(.connectionRequired)
    }
}
