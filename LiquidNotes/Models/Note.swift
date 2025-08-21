//
//  Note.swift
//  LiquidNotes
//
//  Created by Christian Anorga on 8/17/25.
//

import SwiftData
import Foundation
import UIKit

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
    var width: Float = 160  // Default note width
    var height: Float = 120 // Default note height
    var isArchived: Bool = false
    var isFavorited: Bool = false
    var tags: [String] = []
    var attachments: [Data] = [] // Store image/GIF data
    var attachmentTypes: [String] = [] // Store MIME types
    
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
        self.width = 160
        self.height = 120
        self.isArchived = false
        self.isFavorited = false
        self.tags = []
        self.attachments = []
        self.attachmentTypes = []
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
        guard index < attachments.count else { return }
        attachments.remove(at: index)
        attachmentTypes.remove(at: index)
        updateModifiedDate()
    }
}