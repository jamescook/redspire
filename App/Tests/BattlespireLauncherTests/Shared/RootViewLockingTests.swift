import Testing
@testable import BattlespireLauncher

struct RootViewLockingTests {
    @Test func pickerEnabledWhenNoSessionRunning() throws {
        #expect(RootView.isPickerEnabled(isSessionRunning: false) == true)
    }

    @Test func pickerDisabledWhileSessionRunning() throws {
        #expect(RootView.isPickerEnabled(isSessionRunning: true) == false)
    }
}
