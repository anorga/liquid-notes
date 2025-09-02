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
    // Stable IDs aligned with attachments array for token serialization [[ATTACH:<id>]] in content
    var attachmentIDs: [String] = []
    // Full archived rich text (NSAttributedString) representation (preferred new storage)
    var richTextData: Data? = nil
    // Lightweight plain excerpt for fast previews / search (body only, no title)
    var previewExcerpt: String = ""
    // File-based attachment metadata (future: migrate away from in-DB Data arrays)
    var fileAttachmentIDs: [String] = []          // stable IDs
    var fileAttachmentTypes: [String] = []        // MIME types
    var fileAttachmentNames: [String] = []        // stored file names (with extension)
    var fileAttachmentThumbNames: [String] = []   // thumbnail file names (optional)
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
    self.previewExcerpt = ""
    }
    
    var priority: NotePriority {
        get { NotePriority(rawValue: priorityRawValue) ?? .normal }
        set { priorityRawValue = newValue.rawValue }
    }
    
    func updateModifiedDate() {
        modifiedDate = Date()
    }
    
    func addAttachment(data: Data, type: String, id: String = UUID().uuidString) {
    attachments.append(data)
    attachmentTypes.append(type)
    attachmentIDs.append(id)
        updateModifiedDate()
    }
    
    func removeAttachment(at index: Int) {
    guard index < attachments.count && index < attachmentTypes.count && index < attachmentIDs.count else { return }
    attachments.remove(at: index)
    attachmentTypes.remove(at: index)
    attachmentIDs.remove(at: index)
        updateModifiedDate()
    }
    
    func ensureAttachmentIDIntegrity() {
        if attachmentIDs.count != attachments.count {
            // Regenerate IDs for any missing
            if attachmentIDs.count < attachments.count {
                let deficit = attachments.count - attachmentIDs.count
                for _ in 0..<deficit { attachmentIDs.append(UUID().uuidString) }
            } else {
                // Truncate extras (shouldn't happen normally)
                attachmentIDs = Array(attachmentIDs.prefix(attachments.count))
            }
        }
        if attachmentTypes.count != attachments.count {
            // Pad types with generic image type if mismatch
            if attachmentTypes.count < attachments.count {
                let deficit = attachments.count - attachmentTypes.count
                for _ in 0..<deficit { attachmentTypes.append("image/jpeg") }
            } else {
                attachmentTypes = Array(attachmentTypes.prefix(attachments.count))
            }
        }
    }

    // MARK: - File Attachment Helpers (new storage path)
    func addFileAttachment(id: String, type: String, fileName: String, thumbName: String?) {
        fileAttachmentIDs.append(id)
        fileAttachmentTypes.append(type)
        fileAttachmentNames.append(fileName)
        fileAttachmentThumbNames.append(thumbName ?? "")
        updateModifiedDate()
    }

    func removeFileAttachment(id: String) {
        if let idx = fileAttachmentIDs.firstIndex(of: id) {
            // Attempt file deletion
            if let dir = AttachmentFileStore.noteDir(noteID: self.id) {
                if idx < fileAttachmentNames.count {
                    let url = dir.appendingPathComponent(fileAttachmentNames[idx])
                    try? FileManager.default.removeItem(at: url)
                }
                if idx < fileAttachmentThumbNames.count && !fileAttachmentThumbNames[idx].isEmpty {
                    let turl = dir.appendingPathComponent(fileAttachmentThumbNames[idx])
                    try? FileManager.default.removeItem(at: turl)
                }
            }
            fileAttachmentIDs.remove(at: idx)
            if idx < fileAttachmentTypes.count { fileAttachmentTypes.remove(at: idx) }
            if idx < fileAttachmentNames.count { fileAttachmentNames.remove(at: idx) }
            if idx < fileAttachmentThumbNames.count { fileAttachmentThumbNames.remove(at: idx) }
            updateModifiedDate()
        }
    }
    
    func addTask(_ text: String, dueDate: Date? = nil) {
    let task = TaskItem(text: text, note: self, dueDate: dueDate)
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
    var dueDate: Date? = nil
    @Relationship var note: Note?
    
    init(text: String, isCompleted: Bool = false, note: Note? = nil, dueDate: Date? = nil) {
        self.id = UUID()
        self.text = text
        self.isCompleted = isCompleted
        self.createdDate = Date()
        self.note = note
        self.dueDate = dueDate
    }
}

