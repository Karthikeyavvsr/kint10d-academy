import XCTest
@testable import AcademyCore
final class LearningNavigationTests:XCTestCase {
    func testCompletedBookmarkCannotTrapContinue() {
        XCTAssertEqual(LearningNavigation.continueID(orderedIDs:["a","b","c"],completed:["a"],bookmark:"a"),"b")
    }
    func testUnfinishedBookmarkAndUndoRemainResumable() {
        XCTAssertEqual(LearningNavigation.continueID(orderedIDs:["a","b","c"],completed:[],bookmark:"b"),"b")
    }
    func testAllReadAndStaleBookmark() {
        XCTAssertNil(LearningNavigation.continueID(orderedIDs:["a"],completed:["a"],bookmark:"a"))
        XCTAssertEqual(LearningNavigation.continueID(orderedIDs:["a"],completed:[],bookmark:"missing"),"a")
    }
}
