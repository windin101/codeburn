import Foundation
import IOKit.ps

/// Decides how often the background refresh loop may spawn CLI fetches. The
/// 30s timer keeps firing (cheap); this throttles the expensive part - each
/// fetch is a full Node process at 100%+ CPU for seconds (#647). With the
/// popover closed nobody is looking at anything but the status figure, so on
/// battery or in Low Power Mode the spawn cadence backs off. Opening the
/// popover always refreshes immediately via refreshPayloadForPopoverOpen, so
/// the backoff never shows a user stale data they are actually looking at.
enum RefreshCadence {
    static let activeSeconds: TimeInterval = 30
    static let batteryIdleSeconds: TimeInterval = 150
    static let lowPowerIdleSeconds: TimeInterval = 300

    static func interval(popoverOpen: Bool, onBattery: Bool, lowPowerMode: Bool) -> TimeInterval {
        if popoverOpen { return activeSeconds }
        if lowPowerMode { return lowPowerIdleSeconds }
        if onBattery { return batteryIdleSeconds }
        return activeSeconds
    }
}

enum PowerSource {
    static func isOnBattery() -> Bool {
        // Copy function -> retained; Get function -> borrowed (unretained).
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(snapshot)?.takeUnretainedValue() as String?
        else { return false }
        return type == kIOPMBatteryPowerKey
    }
}
