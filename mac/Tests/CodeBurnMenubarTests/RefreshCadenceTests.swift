import XCTest
@testable import CodeBurnMenubar

final class RefreshCadenceTests: XCTestCase {
    func testPopoverOpenAlwaysUsesActiveCadence() {
        XCTAssertEqual(
            RefreshCadence.interval(popoverOpen: true, onBattery: true, lowPowerMode: true),
            RefreshCadence.activeSeconds
        )
    }

    func testIdleOnACStaysActive() {
        XCTAssertEqual(
            RefreshCadence.interval(popoverOpen: false, onBattery: false, lowPowerMode: false),
            RefreshCadence.activeSeconds
        )
    }

    func testIdleOnBatteryBacksOff() {
        XCTAssertEqual(
            RefreshCadence.interval(popoverOpen: false, onBattery: true, lowPowerMode: false),
            RefreshCadence.batteryIdleSeconds
        )
    }

    func testLowPowerModeBacksOffFurthest() {
        XCTAssertEqual(
            RefreshCadence.interval(popoverOpen: false, onBattery: true, lowPowerMode: true),
            RefreshCadence.lowPowerIdleSeconds
        )
        XCTAssertEqual(
            RefreshCadence.interval(popoverOpen: false, onBattery: false, lowPowerMode: true),
            RefreshCadence.lowPowerIdleSeconds
        )
    }

    func testBackoffOrdering() {
        XCTAssertLessThan(RefreshCadence.activeSeconds, RefreshCadence.batteryIdleSeconds)
        XCTAssertLessThan(RefreshCadence.batteryIdleSeconds, RefreshCadence.lowPowerIdleSeconds)
    }
}
