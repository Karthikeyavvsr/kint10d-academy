import XCTest
@testable import AcademyCore
final class MikoTests: XCTestCase {
    func testReducedMotionIsActuallyStatic() {
        for reading in [false, true] {
            let first = MikoMotion.sample(elapsed: 0, reading: reading, reduceMotion: true)
            for time in [5.9, 15.0, 27.0, 10000] {
                XCTAssertEqual(first, MikoMotion.sample(elapsed: time, reading: reading, reduceMotion: true))
            }
        }
    }
    func testWalkStaysOnLedgeAndReturns() {
        for time in stride(from: 0.0, through: 100.0, by: 0.03) {
            let state = MikoMotion.sample(elapsed: time, reading: false, reduceMotion: false)
            XCTAssertTrue((0...1).contains(state.progress))
            XCTAssertTrue((0..<8).contains(state.frame) || (12..<20).contains(state.frame))
            XCTAssertTrue((-5...5).contains(state.tilt))
            XCTAssertTrue((0.97...1.03).contains(state.breath))
        }
        XCTAssertEqual(MikoMotion.sample(elapsed: 10, reading: false, reduceMotion: false).progress, 1)
        XCTAssertEqual(MikoMotion.sample(elapsed: 24, reading: false, reduceMotion: false).progress, 0)
        XCTAssertTrue(MikoMotion.sample(elapsed: 20, reading: false, reduceMotion: false).facesLeft)
    }
    func testIdleIncludesLookingAndGrooming() {
        XCTAssertEqual(MikoMotion.sample(elapsed: 11, reading: false, reduceMotion: false).frame, 13)
        XCTAssertEqual(MikoMotion.sample(elapsed: 25, reading: false, reduceMotion: false).frame, 17)
        XCTAssertEqual(MikoMotion.sample(elapsed: 25, reading: false, reduceMotion: false).progress, 0)
    }
    func testReaderNeverWalksAndOnlyUsesGlassesFrames() {
        for time in stride(from: 0.0, through: 14, by: 0.05) {
            let state = MikoMotion.sample(elapsed: time, reading: true, reduceMotion: false)
            XCTAssertEqual(state.progress, 0)
            XCTAssertTrue([8,9].contains(state.frame))
        }
        XCTAssertEqual(MikoMotion.sample(elapsed: 5.9, reading: true, reduceMotion: false).frame, 9)
    }
}
