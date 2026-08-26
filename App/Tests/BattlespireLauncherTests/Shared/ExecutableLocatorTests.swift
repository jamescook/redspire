import Testing
@testable import BattlespireLauncher

struct ExecutableLocatorTests {
    @Test func returnsFirstMatchingCandidate() {
        let found = ExecutableLocator.firstExecutable(
            in: ["/a/missing", "/b/present", "/c/present-too"],
            isExecutable: { $0 == "/b/present" || $0 == "/c/present-too" }
        )
        #expect(found == "/b/present")
    }

    @Test func returnsNilWhenNoneMatch() {
        let found = ExecutableLocator.firstExecutable(in: ["/a", "/b"], isExecutable: { _ in false })
        #expect(found == nil)
    }

    @Test func returnsNilForEmptyCandidateList() {
        let found = ExecutableLocator.firstExecutable(in: [], isExecutable: { _ in true })
        #expect(found == nil)
    }
}
