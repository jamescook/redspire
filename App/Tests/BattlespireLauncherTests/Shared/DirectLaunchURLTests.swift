import Testing
import Foundation
@testable import Redspire

struct DirectLaunchURLTests {
    @Test func parsesBattlespire() {
        let url = URL(string: "redspire://launch/battlespire")!
        #expect(DirectLaunchURL.parse(url) == .battlespire)
    }

    @Test func parsesRedguard() {
        let url = URL(string: "redspire://launch/redguard")!
        #expect(DirectLaunchURL.parse(url) == .redguard)
    }

    @Test func rejectsWrongScheme() {
        let url = URL(string: "https://launch/battlespire")!
        #expect(DirectLaunchURL.parse(url) == nil)
    }

    @Test func rejectsWrongHost() {
        let url = URL(string: "redspire://open/battlespire")!
        #expect(DirectLaunchURL.parse(url) == nil)
    }

    @Test func rejectsUnknownModeToken() {
        let url = URL(string: "redspire://launch/nonexistent-game")!
        #expect(DirectLaunchURL.parse(url) == nil)
    }

    @Test func roundTripsThroughItsOwnURLBuilder() {
        for mode in GameMode.allCases {
            #expect(DirectLaunchURL.parse(DirectLaunchURL.url(for: mode)) == mode)
        }
    }
}
