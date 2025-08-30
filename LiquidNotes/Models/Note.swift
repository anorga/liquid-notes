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
    var tags: [String] = [] // Restored tags support
    var attachments: [Data] = []
    var attachmentTypes: [String] = []
    
    // var tasks: [TaskItem] = [] // Temporarily commented out for debugging
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
        // self.tasks = [] // Temporarily commented out
    self.dueDate = nil
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
        // let task = TaskItem(text: text)
        // tasks.append(task)
        // updateProgress()
        updateModifiedDate()
    }
    
    func toggleTask(at index: Int) {
        // guard index < tasks.count else { return }
        // tasks[index].isCompleted.toggle()
        // updateProgress()
        updateModifiedDate()
    }
    
    func removeTask(at index: Int) {
        // guard index < tasks.count else { return }
        // tasks.remove(at: index)
        // updateProgress()
        updateModifiedDate()
    }
    
    func updateProgress() {
        // guard !tasks.isEmpty else {
            progress = 0
        //     return
        // }
        // let completedCount = tasks.filter { $0.isCompleted }.count
        // progress = Double(completedCount) / Double(tasks.count)
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
    
    init(text: String, isCompleted: Bool = false) {
        self.id = UUID()
        self.text = text
        self.isCompleted = isCompleted
        self.createdDate = Date()
    }
}

