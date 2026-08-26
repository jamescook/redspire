import Testing
@testable import BattlespireLauncher

struct DiscMounterTests {
    @Test func parsesMountPointFromHdiutilPlist() {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>system-entities</key>
            <array>
                <dict>
                    <key>content-hint</key>
                    <string>Apple_partition_scheme</string>
                    <key>dev-entry</key>
                    <string>/dev/disk4</string>
                </dict>
                <dict>
                    <key>content-hint</key>
                    <string>Apple_ISO</string>
                    <key>dev-entry</key>
                    <string>/dev/disk4s1</string>
                    <key>mount-point</key>
                    <string>/Volumes/BATTLESPIRE</string>
                </dict>
            </array>
        </dict>
        </plist>
        """
        #expect(DiscMounter.parseMountPoint(fromHdiutilPlistOutput: plist) == "/Volumes/BATTLESPIRE")
    }

    @Test func returnsNilForGarbagePlistOutput() {
        #expect(DiscMounter.parseMountPoint(fromHdiutilPlistOutput: "not a plist") == nil)
    }
}
