//
//  Note.swift
//  LiquidNotes
//
//  Created by Christian Anorga on 8/17/25.
//

import SwiftData
import Foundation

@Model
final class Note {
    var id: UUID
    var title: String
    var content: String
    var createdDate: Date
    var modifiedDate: Date
    // Spatial properties for future Phase 2 features
    var positionX: Float
    var positionY: Float
    var zIndex: Int
    var isArchived: Bool
    var isPinned: Bool
    var tags: [String]
    
    var category: NoteCategory?
    
    init(title: String = "", content: String = "") {
        self.id = UUID()
        self.title = title
        self.content = content
        self.createdDate = Date()
        self.modifiedDate = Date()
        self.positionX = 0
        self.positionY = 0
        self.zIndex = 0
        self.isArchived = false
        self.isPinned = false
        self.tags = []
    }
    
    func updateModifiedDate() {
        modifiedDate = Date()
    }
}