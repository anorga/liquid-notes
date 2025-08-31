//
//  Note.swift
//  LiquidNotes
//
//  Created by Christian Anorga on 8/17/25.
//

import SwiftData
import Foundation
import UIKit
import SwiftUI

@Model
final class Note {
    var id: UUID = UUID()
    var title: String = ""
    var content: String = ""
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    // Spatial properties for future Phase 2 features
    var positionX: Float = 0
    var positionY: Float = 0
    var zIndex: Int = 0
    var width: Float = 180
    var height: Float = 140
    var isArchived: Bool = false
    var isFavorited: Bool = false
    // System/internal note not shown in standard lists (e.g., Quick Tasks bucket)
    var isSystem: Bool = false
    var tags: [String] = [] // Restored tags support
    var attachments: [Data] = []
    var attachmentTypes: [String] = []
    // Parsed [[link]] titles referenced in content (resolved lazily by title match)
    var linkedNoteTitles: [String] = []
    // Historical titles for stable link resolution if a note is renamed
    var aliasTitles: [String] = []
    // Resolved linked note UUIDs (stable graph). Maintained by reindexer.
    var linkedNoteIDs: [UUID] = []
    // Graph layout (persisted user-adjusted positions)
    var graphPosX: Double = 0
    var graphPosY: Double = 0
    var hasCustomGraphPosition: Bool = false
    // Link usage metrics (for ranking suggestions)
    var linkUsageCount: Int = 0
    var lastLinkedDate: Date? = nil
    
    @Relationship(deleteRule: .cascade, inverse: \TaskItem.note) var tasks: [TaskItem]? // CloudKit requires optional relationships
    var dueDate: Date?
    var priorityRawValue: String = "normal"
    var progress: Double = 0.0
    
    var category: NoteCategory?
    var folder: Folder?
    
    init(title: String = "", content: String = "") {
        self.id = UUID()
        self.title = title
        self.content = content
        self.createdDate = Date()
        self.modifiedDate = Date()
        self.positionX = 0
        self.positionY = 0
        self.zIndex = 0
        self.width = 180
        self.height = 140
        self.isArchived = false
        self.isFavorited = false
    self.tags = []
    self.attachments = []
    self.attachmentTypes = []  
    self.tasks = []
    self.dueDate = nil
    self.linkedNoteTitles = []
    self.aliasTitles = []
    self.linkedNoteIDs = []
    self.graphPosX = 0
    self.graphPosY = 0
    self.hasCustomGraphPosition = false
    self.linkUsageCount = 0
    self.lastLinkedDate = nil
    }
    
    var priority: NotePriority {
        get { NotePriority(rawValue: priorityRawValue) ?? .normal }
        set { priorityRawValue = newValue.rawValue }
    }
    
    func updateModifiedDate() {
        modifiedDate = Date()
    }
    
    func addAttachment(data: Data, type: String) {
    attachments.append(data)
    attachmentTypes.append(type)
        updateModifiedDate()
    }
    
    func removeAttachment(at index: Int) {
    guard index < attachments.count && index < attachmentTypes.count else { return }
    attachments.remove(at: index)
    attachmentTypes.remove(at: index)
        updateModifiedDate()
    }
    
    func addTask(_ text: String) {
    let task = TaskItem(text: text, note: self)
    // Defensive copy to avoid simultaneous access when UI enumerates tasks
    var copy = tasks ?? []
    copy.append(task)
    tasks = copy
    updateProgress()
    updateModifiedDate()
    }

    func toggleTask(at index: Int) {
    guard let arr = tasks, index < arr.count else { return }
    arr[index].isCompleted = !arr[index].isCompleted
    updateProgress()
    updateModifiedDate()
    }

    func removeTask(at index: Int) {
    guard var arr = tasks, index < arr.count else { return }
    arr.remove(at: index)
    tasks = arr
    updateProgress()
    updateModifiedDate()
    }

    func updateProgress() {
        guard let arr = tasks, !arr.isEmpty else { progress = 0; return }
        let completedCount = arr.filter { $0.isCompleted }.count
        progress = Double(completedCount) / Double(arr.count)
    }
    
    func addTag(_ tag: String) {
        if !tags.contains(tag) {
            tags.append(tag)
            updateModifiedDate()
        }
    }
    
    func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
        updateModifiedDate()
    }
}

// MARK: - Linking Helpers
extension Note {
    /// Extracts [[Linked Note]] style references from the note content and stores the raw titles.
    /// Call this after mutating `content` (typically during save) before persisting context.
    func updateLinkedNoteTitles() {
        let pattern = #"\[\[([^\]]+)\]\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let range = NSRange(location: 0, length: (content as NSString).length)
        let matches = regex.matches(in: content, range: range)
        let titles = matches.compactMap { match -> String? in
            guard match.numberOfRanges >= 2 else { return nil }
            let sub = match.range(at: 1)
            if let swiftRange = Range(sub, in: content) { return String(content[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines) }
            return nil
        }
        linkedNoteTitles = Array(Set(titles)).sorted()
    }

    /// Records previous title as alias if changed and non-empty.
    func recordTitleAlias(previousTitle: String, newTitle: String) {
        let old = previousTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let new = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !old.isEmpty, !new.isEmpty, old != new else { return }
        if !aliasTitles.contains(old) { aliasTitles.append(old) }
    }
}

@Model
final class TaskItem {
    var id: UUID = UUID()
    var text: String = ""
    var isCompleted: Bool = false
    var createdDate: Date = Date()
    @Relationship var note: Note?
    
    init(text: String, isCompleted: Bool = false, note: Note? = nil) {
        self.id = UUID()
        self.text = text
        self.isCompleted = isCompleted
        self.createdDate = Date()
        self.note = note
    }
}

