//
//  NoteCategory.swift
//  LiquidNotes
//
//  Created by Christian Anorga on 8/17/25.
//

import SwiftData
import Foundation

@Model
final class NoteCategory {
    var id: UUID
    var name: String
    var color: String
    var createdDate: Date
    
    @Relationship(deleteRule: .cascade, inverse: \Note.category)
    var notes: [Note]
    
    init(name: String, color: String = "blue") {
        self.id = UUID()
        self.name = name
        self.color = color
        self.createdDate = Date()
        self.notes = []
    }
    
    var noteCount: Int {
        notes.count
    }
    
    var activeNoteCount: Int {
        notes.filter { !$0.isArchived }.count
    }
}