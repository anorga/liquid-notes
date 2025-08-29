//
//  LiquidNotesWidget.swift
//  LiquidNotesWidget
//
//  Created by Christian Anorga on 8/17/25.
//

import WidgetKit
import SwiftUI
import SwiftData

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), notes: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), notes: getSampleNotes())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let notes = loadNotes()
        let entry = SimpleEntry(date: Date(), notes: notes)
        
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func loadNotes() -> [WidgetNote] {
        return getSampleNotes()
    }
    
    private func getSampleNotes() -> [WidgetNote] {
        return []
    }
}

struct WidgetNote: Identifiable {
    let id = UUID()
    let title: String
    let content: String
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
            EmptyWidgetView()
        }
    }
}

struct MediumWidgetView: View {
    let notes: [WidgetNote]
    
    var body: some View {
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

struct LargeWidgetView: View {
    let notes: [WidgetNote]
    
    var body: some View {
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

struct WidgetNoteCard: View {
    let note: WidgetNote
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !note.title.isEmpty {
                Text(note.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            
            if !note.content.isEmpty {
                Text(note.content)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            
            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .opacity(0.8)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
        WidgetNote(title: "Sample Note", content: "This is a preview note")
    ])
}
