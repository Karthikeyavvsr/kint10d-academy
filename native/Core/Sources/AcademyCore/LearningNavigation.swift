import Foundation

public enum LearningNavigation {
    public static func continueID(orderedIDs:[String], completed:Set<String>, bookmark:String?) -> String? {
        if let bookmark,orderedIDs.contains(bookmark),!completed.contains(bookmark) {return bookmark}
        return orderedIDs.first{!completed.contains($0)}
    }
}
