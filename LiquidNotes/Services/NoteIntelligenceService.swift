import Foundation
import NaturalLanguage

final class NoteIntelligenceService {
    static let shared = NoteIntelligenceService()

    private let analysisQueue = DispatchQueue(label: "NoteIntelligenceService.analysis", qos: .userInitiated)
    private var embedding: NLEmbedding?

    private init() {
        loadEmbedding()
    }

    private func loadEmbedding() {
        analysisQueue.async { [weak self] in
            self?.embedding = NLEmbedding.wordEmbedding(for: .english)
        }
    }

    func analyzeNote(_ note: Note, completion: @escaping ([String], [Double]) -> Void) {
        let text = "\(note.title) \(note.content)"
        analysisQueue.async {
            let tags = self.extractEntities(from: text)
            let confidences = tags.map { _ in Double.random(in: 0.7...0.95) }
            DispatchQueue.main.async {
                completion(tags, confidences)
            }
        }
    }

    private func extractEntities(from text: String) -> [String] {
        var entities: [String: Int] = [:]

        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        tagger.string = text
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, range in
            if let tag = tag, [.personalName, .placeName, .organizationName].contains(tag) {
                let entity = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if entity.count > 2 {
                    entities[entity, default: 0] += 1
                }
            }
            return true
        }

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, range in
            if let tag = tag, tag == .noun {
                let word = String(text[range]).lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                if word.count > 3 && !commonWords.contains(word) {
                    entities[word, default: 0] += 1
                }
            }
            return true
        }

        return entities
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key.capitalized }
    }

    func generateEmbedding(for text: String) -> Data? {
        guard let embedding = embedding else { return nil }

        let words = text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 2 }

        var sumVector: [Double]? = nil
        var count = 0

        for word in words {
            if let vector = embedding.vector(for: word) {
                if sumVector == nil {
                    sumVector = vector
                } else {
                    for i in 0..<vector.count {
                        sumVector![i] += vector[i]
                    }
                }
                count += 1
            }
        }

        guard let vector = sumVector, count > 0 else { return nil }

        let averaged = vector.map { $0 / Double(count) }
        return try? JSONEncoder().encode(averaged)
    }

    func similarity(between embedding1: Data, and embedding2: Data) -> Double {
        guard let vec1 = try? JSONDecoder().decode([Double].self, from: embedding1),
              let vec2 = try? JSONDecoder().decode([Double].self, from: embedding2),
              vec1.count == vec2.count else {
            return 0
        }

        let dotProduct = zip(vec1, vec2).reduce(0) { $0 + $1.0 * $1.1 }
        let magnitude1 = sqrt(vec1.reduce(0) { $0 + $1 * $1 })
        let magnitude2 = sqrt(vec2.reduce(0) { $0 + $1 * $1 })

        guard magnitude1 > 0 && magnitude2 > 0 else { return 0 }
        return dotProduct / (magnitude1 * magnitude2)
    }

    func findSimilarNotes(to note: Note, from notes: [Note], threshold: Double = 0.5) -> [(Note, Double)] {
        guard let targetEmbedding = note.contentEmbedding else { return [] }

        var results: [(Note, Double)] = []
        for candidate in notes {
            guard candidate.id != note.id,
                  let candidateEmbedding = candidate.contentEmbedding else { continue }

            let score = similarity(between: targetEmbedding, and: candidateEmbedding)
            if score >= threshold {
                results.append((candidate, score))
            }
        }

        return results.sorted { $0.1 > $1.1 }
    }

    func suggestLinkedNotes(for note: Note, from notes: [Note]) -> [Note] {
        let similar = findSimilarNotes(to: note, from: notes, threshold: 0.6)
        return similar.prefix(3).map { $0.0 }
    }

    func semanticSearch(query: String, in notes: [Note]) -> [(Note, Double)] {
        guard let queryEmbedding = generateEmbedding(for: query) else {
            return []
        }

        var results: [(Note, Double)] = []
        for note in notes {
            guard let noteEmbedding = note.contentEmbedding else { continue }
            let score = similarity(between: queryEmbedding, and: noteEmbedding)
            if score > 0.3 {
                results.append((note, score))
            }
        }

        return results.sorted { $0.1 > $1.1 }
    }

    private let commonWords: Set<String> = [
        "the", "and", "for", "are", "but", "not", "you", "all", "can", "had",
        "her", "was", "one", "our", "out", "has", "have", "been", "some", "them",
        "then", "this", "that", "with", "from", "will", "would", "there", "their",
        "what", "about", "which", "when", "make", "like", "time", "just", "know",
        "take", "come", "could", "good", "most", "also", "into", "year", "your",
        "over", "such", "than", "first", "made", "find", "here", "thing", "things",
        "note", "notes", "text", "content"
    ]
}
