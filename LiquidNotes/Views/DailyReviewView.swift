import SwiftUI
import SwiftData

struct DailyReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.modifiedDate, order: .reverse) private var allNotes: [Note]
    private var today = Calendar.current.startOfDay(for: Date())
    private var staleCutoff: Date { Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date() }
    private var recent: [Note] { allNotes.filter { !$0.isArchived && $0.modifiedDate >= today } }
    private var overdue: [Note] { allNotes.filter { !$0.isArchived && ($0.dueDate ?? Date.distantFuture) < Date() } }
    private var staleImportant: [Note] { allNotes.filter { !$0.isArchived && $0.isFavorited && $0.modifiedDate < staleCutoff } }
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidNotesBackground().ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        LNHeader(title: "Daily Review") { EmptyView() }
                        VStack(spacing: 28) {
                            SectionCard(title: "Today Edited", icon: "clock.badge.checkmark", color: .blue, notes: recent)
                            SectionCard(title: "Overdue", icon: "exclamationmark.triangle", color: .orange, notes: overdue)
                            SectionCard(title: "Revisit Favorites", icon: "arrow.counterclockwise", color: .purple, notes: staleImportant)
                        }
                        .padding(.horizontal, UI.Space.xl)
                        .padding(.top, UI.Space.l)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
}

private struct SectionCard: View {
    let title: String
    let icon: String
    let color: Color
    let notes: [Note]
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: icon).foregroundStyle(color)
                Text(title).font(.headline).fontWeight(.semibold)
                Spacer()
                Text("\(notes.count)").font(.caption).foregroundStyle(.secondary)
            }
            if notes.isEmpty {
                Text("Nothing here 🎉")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 10) {
                    ForEach(notes.prefix(6), id: \.id) { note in
                        HStack(alignment: .top, spacing: 10) {
                            Circle().fill(color.opacity(0.25)).frame(width: 10, height: 10)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(note.title.isEmpty ? "Untitled" : note.title)
                                    .font(.subheadline).fontWeight(.medium).lineLimit(1)
                                if !note.content.isEmpty {
                                    Text(note.content).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                }
                            }
                            Spacer()
                            if let due = note.dueDate { Text(due.ln_dayDistanceString()).font(.caption2).foregroundStyle(.secondary) }
                        }
                        .padding(.horizontal, UI.Space.m).padding(.vertical, UI.Space.s)
                        .background(RoundedRectangle(cornerRadius: UI.Corner.s).fill(Color.secondary.opacity(0.07)))
                    }
                }
            }
        }
        .padding(UI.Space.l)
        .background(.clear)
        .premiumGlassCard()
    }
}

#Preview { DailyReviewView().modelContainer(for: [Note.self]) }
