import Foundation
public struct CompletedReading {
    public let minutes:Int
    public let date:Date
    public init(minutes:Int,date:Date){self.minutes=minutes;self.date=date}
}
public struct PaceEstimate {
    public let readingMinutesPerDay:Double?
    public let daysRemaining:Double?
    public let sampleDays:Int
    public let recentCompletions:Int
    public static func calculate(remainingMinutes:Int,completions:[CompletedReading],started:Date,now:Date=Date(),calendar:Calendar = .current)->PaceEstimate {
        let elapsed=max(1,(calendar.dateComponents([.day],from:calendar.startOfDay(for:started),to:calendar.startOfDay(for:now)).day ?? 0)+1)
        let days=min(14,elapsed)
        let cutoff=calendar.date(byAdding:.day,value:-(days-1),to:calendar.startOfDay(for:now))!
        let recent=completions.filter{$0.date>=cutoff && $0.date<=now && $0.minutes>0}
        let earned=recent.reduce(0){$0+$1.minutes}
        guard elapsed>=3,recent.count>=3,earned>0 else{return PaceEstimate(readingMinutesPerDay:nil,daysRemaining:nil,sampleDays:days,recentCompletions:recent.count)}
        let rate=Double(earned)/Double(days)
        return PaceEstimate(readingMinutesPerDay:rate,daysRemaining:Double(max(0,remainingMinutes))/rate,sampleDays:days,recentCompletions:recent.count)
    }
}
