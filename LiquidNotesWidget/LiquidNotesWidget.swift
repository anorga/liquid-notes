//
//  LiquidNotesWidget.swift
//  LiquidNotesWidget
//
//  Created by Christian Anorga on 8/17/25.
//

import WidgetKit
import SwiftUI
import AppIntents

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        print("🟡 Widget: placeholder() called")
        return SimpleEntry(date: Date(), notes: getSampleNotes())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        print("🟡 Widget: getSnapshot called, isPreview: \(context.isPreview)")
        let notes = loadNotes()
        let entry = SimpleEntry(date: Date(), notes: notes)
        print("🟡 Widget: getSnapshot completed with \(notes.count) notes")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        print("🟡 Widget: getTimeline called")
        let notes = loadNotes()
        let entry = SimpleEntry(date: Date(), notes: notes)
        
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        print("🟡 Widget: getTimeline completed with \(notes.count) notes, next update: \(nextUpdate)")
        completion(timeline)
    }
    
    private func loadNotes() -> [WidgetNote] {
        print("🟡 Widget: loadNotes() called at \(Date())")
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.liquidnotes.shared"
        ) else { 
            print("🔴 Widget: No shared container URL found")
            return []
        }
        
        print("🟡 Widget: Loading notes from shared container: \(containerURL)")
        let widgetDataURL = containerURL.appendingPathComponent("widget_notes.json")
        print("🟡 Widget: Checking file at: \(widgetDataURL)")
        
        // List all files in the container to debug
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: containerURL.path)
            print("🟡 Widget: Files in container: \(files)")
        } catch {
            print("🔴 Widget: Cannot list container contents: \(error)")
        }
        
        // Check if file exists
        if !FileManager.default.fileExists(atPath: widgetDataURL.path) {
            print("🔴 Widget: widget_notes.json file does NOT exist at \(widgetDataURL.path)")
            return []
        }
        
        do {
            let data = try Data(contentsOf: widgetDataURL)
            print("🟡 Widget: Read \(data.count) bytes from file")
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let widgetData = try decoder.decode([WidgetNoteData].self, from: data)
            
            print("🟢 Widget: Successfully loaded \(widgetData.count) notes")
            print("🟢 Widget: Note titles: \(widgetData.map { $0.title })")
            
            let widgetNotes = widgetData.map { data in
                WidgetNote(
                    id: UUID(uuidString: data.id) ?? UUID(),
                    title: data.title,
                    content: data.content,
                    isFavorited: data.isFavorited,
                    hasTask: data.hasTask,
                    taskProgress: data.taskCount > 0 ? Double(data.completedTaskCount) / Double(data.taskCount) : 0,
                    tags: data.tags
                )
            }
            
            print("🟢 Widget: Returning \(widgetNotes.count) widget notes")
            return widgetNotes
        } catch {
            print("🔴 Widget: Failed to load notes: \(error)")
            print("🔴 Widget: Error details: \(error.localizedDescription)")
            return []
        }
    }
    
    private func getSampleNotes() -> [WidgetNote] {
        print("🟡 Widget: getSampleNotes() called - returning sample data")
        return [
            WidgetNote(
                id: UUID(),
                title: "Welcome to Liquid Notes",
                content: "Your notes will appear here",
                isFavorited: false,
                hasTask: false,
                taskProgress: 0,
                tags: ["welcome"]
            )
        ]
    }
}

struct WidgetNoteData: Codable {
    let id: String
    let title: String
    let content: String
    let isFavorited: Bool
    let hasTask: Bool
    let taskCount: Int
    let completedTaskCount: Int
    let modifiedDate: Date
    let tags: [String]
}

struct WidgetNote: Identifiable {
    let id: UUID
    let title: String
    let content: String
    let isFavorited: Bool
    let hasTask: Bool
    let taskProgress: Double
    let tags: [String]
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let notes: [WidgetNote]
}

struct LiquidNotesWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        ZStack {
            // Background
            Color.clear
            
            switch family {
            case .systemSmall:
                SmallWidgetView(notes: entry.notes)
            case .systemMedium:
                MediumWidgetView(notes: entry.notes)
            case .systemLarge:
                LargeWidgetView(notes: entry.notes)
            default:
                SmallWidgetView(notes: entry.notes)
            }
        }
        .containerBackground(.clear, for: .widget)
    }
}

struct SmallWidgetView: View {
    let notes: [WidgetNote]
    
    var body: some View {
        if let note = notes.first {
            WidgetNoteCard(note: note)
        } else {
            VStack {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundStyle(.orange)
                
                Text("No Data")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Text("Debug: \(notes.count) notes")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .opacity(0.6)
            )
        }
    }
}

struct MediumWidgetView: View {
    let notes: [WidgetNote]
    
    var body: some View {
        if notes.isEmpty {
            VStack {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundStyle(.orange)
                
                Text("No Data (Medium)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Text("Debug: \(notes.count) notes")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .opacity(0.6)
            )
        } else {
            HStack(spacing: 8) {
                ForEach(notes.prefix(2), id: \.id) { note in
                    WidgetNoteCard(note: note)
                }
                
                if notes.count < 2 {
                    EmptyWidgetView()
                }
            }
            .padding(8)
        }
    }
}

struct LargeWidgetView: View {
    let notes: [WidgetNote]
    
    var body: some View {
        if notes.isEmpty {
            VStack {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundStyle(.orange)
                
                Text("No Data (Large)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Text("Debug: \(notes.count) notes")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .opacity(0.6)
            )
        } else {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(notes.prefix(2), id: \.id) { note in
                        WidgetNoteCard(note: note)
                    }
                }
                
                if notes.count > 2 {
                    HStack(spacing: 8) {
                        ForEach(notes.dropFirst(2).prefix(2), id: \.id) { note in
                            WidgetNoteCard(note: note)
                        }
                    }
                }
            }
            .padding(8)
        }
    }
}

struct WidgetNoteCard: View {
    let note: WidgetNote
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        Link(destination: URL(string: "liquidnotes://note/\(note.id)")!) {
            noteCardContent
        }
    }
    
    private var noteCardContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if !note.title.isEmpty {
                    Text(note.title)
                        .font(family == .systemSmall ? .caption : .footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            
            if !note.content.isEmpty {
                Text(note.content)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(family == .systemSmall ? 2 : 3)
            }
            
            if note.hasTask {
                HStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 2)
                        Circle()
                            .trim(from: 0, to: note.taskProgress)
                            .stroke(
                                LinearGradient(
                                    colors: [.green, .mint],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 12, height: 12)
                    
                    Text("\(Int(note.taskProgress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            if !note.tags.isEmpty && family != .systemSmall {
                HStack(spacing: 4) {
                    ForEach(note.tags.prefix(2), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 8))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.2))
                            )
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct EmptyWidgetView: View {
    var body: some View {
        VStack {
            Image(systemName: "note.text")
                .font(.title2)
                .foregroundStyle(.tertiary)
            
            Text("No Notes")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .opacity(0.6)
        )
    }
}

struct LiquidNotesWidget: Widget {
    let kind: String = "LiquidNotesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LiquidNotesWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Liquid Notes")
        .description("Your notes with beautiful liquid glass effects")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemSmall) {
    LiquidNotesWidget()
} timeline: {
    SimpleEntry(date: .now, notes: [
        WidgetNote(
            id: UUID(),
            title: "Sample Note",
            content: "This is a preview note",
            isFavorited: true,
            hasTask: true,
            taskProgress: 0.7,
            tags: ["sample", "preview"]
        )
    ])
}
