import XCTest
@testable import AcademyCore
final class CoreTests: XCTestCase {
    func testSecondDeviceDoesNotResetStudyStart() {
        let a=ProgressRecord(key:"setting:started",value:"2026-01-01T00:00:00Z",updated:"2026-01-01T00:00:00Z")
        let b=ProgressRecord(key:a.key,value:"2026-01-05T00:00:00Z",updated:"2026-01-05T00:00:00Z")
        XCTAssertEqual(ProgressLogic.merge([a.key:a],[b.key:b])[a.key],a)
        XCTAssertEqual(ProgressLogic.merge([b.key:b],[a.key:a])[a.key],a)
    }
    func testBundledCurriculumDecodes() throws {
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources")
        let lessons=try JSONDecoder().decode([Lesson].self,from:Data(contentsOf:root.appendingPathComponent("curriculum.json")))
        let papers=try JSONDecoder().decode([Paper].self,from:Data(contentsOf:root.appendingPathComponent("papers.json")))
        let resources=try JSONDecoder().decode([Resource].self,from:Data(contentsOf:root.appendingPathComponent("resources.json")))
        XCTAssertEqual(lessons.count,32);XCTAssertEqual(papers.count,22);XCTAssertEqual(resources.count,77)
        XCTAssertTrue(lessons.allSatisfy{$0.minutes>0 && !$0.sections.isEmpty})
    }
    func testLabArithmetic() {
        XCTAssertEqual(LabMath.weightGB(billions: 113,bits: 16),226)
        XCTAssertEqual(LabMath.gradientStep(weight: 4,rate: 0.1),3.4,accuracy: 0.00001)
        XCTAssertEqual(LabMath.bondPrice(yield: 6),1000,accuracy: 0.00001)
        XCTAssertEqual(LabMath.attention(temperature: 1).reduce(0,+),1,accuracy: 0.00001)
        XCTAssertLessThan(LabMath.capital(riskPercent: 1,losses: 10),10000)
    }
    func testMergeKeepsNewerRecordAndUndo() {
        let old = ProgressRecord(key:"lesson:ai-01",value:"read",updated:"2026-01-01T00:00:00Z")
        let new = ProgressRecord(key:"lesson:ai-01",value:"reading",updated:"2026-01-02T00:00:00.001Z")
        XCTAssertEqual(ProgressLogic.merge([old.key:old],[new.key:new])[old.key]?.value,"reading")
        XCTAssertEqual(ProgressLogic.merge([new.key:new],[old.key:old])[old.key]?.value,"reading")
    }
    func testMergeIsDeterministicOnEqualDates() {
        let a = ProgressRecord(key:"note:test",value:"A",updated:"2026-01-01T00:00:00Z")
        let b = ProgressRecord(key:"note:test",value:"B",updated:a.updated)
        XCTAssertEqual(ProgressLogic.merge([a.key:a],[b.key:b]),ProgressLogic.merge([b.key:b],[a.key:a]))
    }
    func testRoundTripAndRejectBadOwnerlessKey() throws {
        let a = ProgressRecord(key:"note:test",value:"My own explanation")
        let data = try JSONEncoder().encode(Snapshot(records:[a.key:a]))
        XCTAssertEqual(try ProgressLogic.decode(data).records[a.key],a)
        let bad = try JSONEncoder().encode(Snapshot(records:["wrong":a]))
        XCTAssertThrowsError(try ProgressLogic.decode(bad))
    }
    func testRecallIntervals() {
        XCTAssertEqual(Recall(success:false,previousDays:16).days,1)
        XCTAssertEqual(Recall(success:true,previousDays:1).days,2)
        XCTAssertEqual(Recall(success:true,previousDays:16).days,30)
    }
}

final class PaceTests:XCTestCase {
    func testNoInstantPaceFromFirstDay() {
        let now=Date()
        let estimate=PaceEstimate.calculate(remainingMinutes:100,completions:[CompletedReading(minutes:30,date:now)],started:now,now:now)
        XCTAssertNil(estimate.daysRemaining)
    }
    func testIncludesDaysWithoutCompletions() {
        var calendar=Calendar(identifier:.gregorian);calendar.timeZone=TimeZone(secondsFromGMT:0)!
        let start=ProgressLogic.date("2026-01-01T00:00:00Z")!
        let now=ProgressLogic.date("2026-01-07T12:00:00Z")!
        let estimate=PaceEstimate.calculate(remainingMinutes:140,completions:(1...3).map{CompletedReading(minutes:35,date:start.addingTimeInterval(Double($0)*86400))},started:start,now:now,calendar:calendar)
        XCTAssertEqual(estimate.readingMinutesPerDay!,15,accuracy:0.0001)
        XCTAssertEqual(estimate.daysRemaining!,140/15.0,accuracy:0.0001)
    }
}
