import Testing
@testable import Redspire

struct RootViewLockingTests {
    @Test func pickerEnabledWhenNoSessionRunning() throws {
        #expect(RootView.isPickerEnabled(isSessionRunning: false) == true)
    }

    @Test func pickerDisabledWhileSessionRunning() throws {
        #expect(RootView.isPickerEnabled(isSessionRunning: true) == false)
    }
}
