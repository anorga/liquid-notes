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
    // SHA256 (hex) of the tokenized archived rich text to skip redundant saves
    var richTextHash: String = ""
    // Lightweight plain excerpt for fast previews / search (body only, no title)
    var previewExcerpt: String = ""
    // File-based attachment metadata (future: migrate away from in-DB Data arrays)
    var fileAttachmentIDs: [String] = []          // stable IDs
    var fileAttachmentTypes: [String] = []        // MIME types
    var fileAttachmentNames: [String] = []        // stored file names (with extension)
    var fileAttachmentThumbNames: [String] = []   // thumbnail file names (optional)
    // One-time flag to prevent repeated legacy attachment migration
    var legacyMigrationDone: Bool = false
    
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
    self.previewExcerpt = ""
    self.legacyMigrationDone = false
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
    
    // Schedule notification if due date is set
    if let dueDate = dueDate, dueDate > Date() {
        SharedDataManager.shared.scheduleTaskNotification(for: task, in: self)
    }
    }

    func toggleTask(at index: Int) {
    guard let arr = tasks, index < arr.count else { return }
    arr[index].isCompleted = !arr[index].isCompleted
    updateProgress()
    updateModifiedDate()
    }

    func removeTask(at index: Int) {
    guard var arr = tasks, index < arr.count else { return }
    let task = arr[index]
    SharedDataManager.shared.cancelTaskNotification(for: task.id)
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

