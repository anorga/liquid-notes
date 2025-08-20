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
    var id: UUID = UUID()
    var name: String = ""
    var color: String = "blue"
    var createdDate: Date = Date()
    
    @Relationship(deleteRule: .nullify, inverse: \Note.category)
    var notes: [Note]?
    
    init(name: String, color: String = "blue") {
        self.id = UUID()
        self.name = name
        self.color = color
        self.createdDate = Date()
        self.notes = nil
    }
    
    var noteCount: Int {
        notes?.count ?? 0
    }
    
    var activeNoteCount: Int {
        notes?.filter { !$0.isArchived }.count ?? 0
    }
}