//
//  Folder.swift
//  LiquidNotes
//
//  Created by Christian Anorga on 8/20/25.
//

import SwiftData
import Foundation

@Model
final class Folder {
    var id: UUID = UUID()
    var name: String = ""
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    // Spatial properties for canvas positioning
    var positionX: Float = 0
    var positionY: Float = 0
    var zIndex: Int = 0
    var isFavorited: Bool = false
    var color: String = "blue"
    
    // Relationship to notes contained in this folder - MUST be optional for CloudKit
    @Relationship(deleteRule: .nullify, inverse: \Note.folder)
    var notes: [Note]?
    
    init(name: String = "New Folder") {
        self.id = UUID()
        self.name = name
        self.createdDate = Date()
        self.modifiedDate = Date()
        self.positionX = 0
        self.positionY = 0
        self.zIndex = 0
        self.isFavorited = false
        self.color = "blue"
        self.notes = nil
    }
    
    func updateModifiedDate() {
        modifiedDate = Date()
    }
    
    var noteCount: Int {
        notes?.count ?? 0
    }
}