import Foundation

public struct Lesson: Codable, Identifiable, Hashable {
    public let id, track, title, level, summary: String
    public let minutes: Int
    public let prerequisites: [String]
    public let sections: [Section]
    public let exercise: Exercise
    public let interview: Interview
    public let quiz: Quiz
    public let sources: [Source]
    public let lab: String?
    public struct Section: Codable, Hashable { public let title, body: String }
    public struct Exercise: Codable, Hashable { public let prompt, solution: String }
    public struct Interview: Codable, Hashable { public let question, answer: String }
    public struct Quiz: Codable, Hashable { public let question: String; public let options: [String]; public let correct: Int; public let explanation: String }
    public struct Source: Codable, Hashable { public let title, url: String }
}
public struct Paper: Codable, Identifiable {
    public let id, title, area, authors, url, why, readFor, limits, exercise: String
    public let prerequisites: TextList
    public enum TextList: Codable, CustomStringConvertible {
        case text(String), list([String])
        public init(from decoder:Decoder)throws{
            let c=try decoder.singleValueContainer()
            if let values=try? c.decode([String].self){self = .list(values)}else{self = .text(try c.decode(String.self))}
        }
        public func encode(to encoder:Encoder)throws{
            var c=encoder.singleValueContainer()
            switch self{case .text(let s):try c.encode(s);case .list(let a):try c.encode(a)}
        }
        public var description:String{switch self{case .text(let s):return s;case .list(let a):return a.joined(separator:", ")}}
    }
    public let year: Year
    public enum Year: Codable, CustomStringConvertible {
        case number(Int), text(String)
        public init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let n = try? c.decode(Int.self) { self = .number(n) } else { self = .text(try c.decode(String.self)) }
        }
        public func encode(to encoder: Encoder) throws {
            var c = encoder.singleValueContainer()
            switch self { case .number(let n): try c.encode(n); case .text(let s): try c.encode(s) }
        }
        public var description: String { switch self { case .number(let n): return String(n); case .text(let s): return s } }
    }
}
public struct Resource: Codable, Identifiable {
    public let id, title, url, format, level, access, verification, study_focus: String
}
public struct ProgressRecord: Codable, Equatable {
    public var key, value: String
    public var revision: Int
    public var updated: String
    public init(key: String, value: String, revision: Int = 1, updated: String = ISO8601DateFormatter().string(from: Date())) {
        self.key = key; self.value = value; self.revision = revision; self.updated = updated
    }
}
public struct Snapshot: Codable {
    public var records: [String: ProgressRecord]
    public var exported: String
    public init(records: [String: ProgressRecord], exported: String = ISO8601DateFormatter().string(from: Date())) { self.records = records; self.exported = exported }
}
public struct Bookmark: Codable { public var lesson: String; public var section: Int; public init(lesson: String, section: Int) { self.lesson = lesson; self.section = section } }
public struct Recall: Codable {
    public var success: Bool
    public var days: Int
    public var due: Double
    public var at: Double
    public init(success: Bool, previousDays: Int, now: Date = Date()) {
        self.success = success; days = success ? min(30, max(1, previousDays) * 2) : 1
        at = now.timeIntervalSince1970 * 1000; due = at + Double(days) * 86_400_000
    }
}
public enum ProgressLogic {
    public static func date(_ string: String) -> Date? {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }
    public static func timestamp(_ now: Date = Date()) -> String {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: now)
    }
    public static func decode(_ data: Data) throws -> Snapshot {
        guard data.count <= 5_000_000 else { throw ValidationError.invalid("File exceeds 5 MB.") }
        let snapshot = try JSONDecoder().decode(Snapshot.self, from: data)
        guard snapshot.records.count <= 5000 else { throw ValidationError.invalid("Too many records.") }
        for (key, record) in snapshot.records {
            guard key == record.key, key.range(of: "^(lesson|paper|resource|note|review|quiz|bookmark|setting|capstone):[a-zA-Z0-9_-]{1,100}$", options: .regularExpression) != nil,
                  record.value.utf8.count <= 20000, record.revision >= 0, date(record.updated) != nil else { throw ValidationError.invalid("Invalid progress record.") }
        }
        return snapshot
    }
    public static func merge(_ local: [String: ProgressRecord], _ incoming: [String: ProgressRecord]) -> [String: ProgressRecord] {
        var result = local
        for (key, remote) in incoming {
            guard let current = result[key] else { result[key] = remote; continue }
            if key == "setting:started", let a=date(current.value), let b=date(remote.value) {
                if b<a {result[key]=remote}
                continue
            }
            let remoteDate = date(remote.updated) ?? .distantPast, localDate = date(current.updated) ?? .distantPast
            if remoteDate > localDate || (remoteDate == localDate && remote.value > current.value) { result[key] = remote }
        }
        return result
    }
    public enum ValidationError: LocalizedError {
        case invalid(String)
        public var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
    }
}
public enum LabMath {
    public static func weightGB(billions: Double, bits: Double) -> Double { billions * bits / 8 }
    public static func gradientStep(weight: Double, rate: Double) -> Double { weight - rate * 2 * (weight - 1) }
    public static func bondPrice(yield: Double) -> Double {
        (1...5).reduce(0) { $0 + 60 / pow(1 + yield / 100, Double($1)) } + 1000 / pow(1 + yield / 100, 5)
    }
    public static func capital(riskPercent: Double, losses: Int) -> Double { 10000 * pow(1-riskPercent/100, Double(losses)) }
    public static func attention(temperature: Double) -> [Double] {
        let scaled = [1.0,2,3].map { exp(($0-3) / max(0.1, temperature)) }
        let sum = scaled.reduce(0,+); return scaled.map { $0/sum }
    }
}
