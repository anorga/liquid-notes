//
//  DataContainer.swift
//  LiquidNotes
//
//  Created by Christian Anorga on 8/17/25.
//

import SwiftData
import SwiftUI

actor DataContainer {
    static let shared = DataContainer()
    
    private init() {}
    
    @MainActor
    static var modelContainer: ModelContainer = {
        let schema = Schema([
            Note.self,
            NoteCategory.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    @MainActor
    static var previewContainer: ModelContainer = {
        let schema = Schema([
            Note.self,
            NoteCategory.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            "LiquidNotesPreview",
            schema: schema,
            isStoredInMemoryOnly: true
        )
        
        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            
            // Create sample data for previews
            let context = container.mainContext
            
            let sampleCategory = NoteCategory(name: "Work", color: "blue")
            context.insert(sampleCategory)
            
            let sampleNote1 = Note(
                title: "Meeting Notes",
                content: "Discuss Q4 roadmap and feature priorities"
            )
            sampleNote1.category = sampleCategory
            context.insert(sampleNote1)
            
            let sampleNote2 = Note(
                title: "Grocery List",
                content: "Milk, Bread, Eggs, Coffee"
            )
            context.insert(sampleNote2)
            
            try? context.save()
            
            return container
        } catch {
            fatalError("Could not create preview ModelContainer: \(error)")
        }
    }()
}