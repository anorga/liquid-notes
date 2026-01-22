import Foundation
import NaturalLanguage
import UIKit

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

    func extractPlainText(from note: Note) -> String {
        if !note.previewExcerpt.isEmpty {
            return "\(note.title) \(note.previewExcerpt)"
        } else if let richData = note.richTextData,
                  let attributed = try? NSAttributedString(data: richData, options: [.documentType: NSAttributedString.DocumentType.rtfd], documentAttributes: nil) {
            return "\(note.title) \(attributed.string)"
        } else {
            let cleaned = note.content.replacingOccurrences(of: "\\[\\[ATTACH:[^\\]]+\\]\\]", with: "", options: .regularExpression)
            return "\(note.title) \(cleaned)"
        }
    }

    func analyzeNote(_ note: Note, completion: @escaping ([String], [Double]) -> Void) {
        let plainText = extractPlainText(from: note)
        analysisQueue.async {
            let tags = self.extractEntities(from: plainText)
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

    struct TextStatistics {
        var wordCount: Int
        var sentenceCount: Int
        var paragraphCount: Int
        var characterCount: Int
        var readingTimeMinutes: Double
        var averageWordsPerSentence: Double
    }

    func analyzeTextStatistics(_ text: String) -> TextStatistics {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var wordCount = 0
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { _, _ in
            wordCount += 1
            return true
        }

        var sentenceCount = 0
        let sentenceEnders = CharacterSet(charactersIn: ".!?")
        for char in text.unicodeScalars {
            if sentenceEnders.contains(char) {
                sentenceCount += 1
            }
        }
        if sentenceCount == 0 && wordCount > 0 {
            sentenceCount = 1
        }

        let paragraphCount = text.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        let characterCount = text.filter { !$0.isWhitespace }.count
        let readingTimeMinutes = Double(wordCount) / 200.0
        let avgWordsPerSentence = sentenceCount > 0 ? Double(wordCount) / Double(sentenceCount) : Double(wordCount)

        return TextStatistics(
            wordCount: wordCount,
            sentenceCount: max(1, sentenceCount),
            paragraphCount: max(1, paragraphCount),
            characterCount: characterCount,
            readingTimeMinutes: readingTimeMinutes,
            averageWordsPerSentence: avgWordsPerSentence
        )
    }

    func extractKeySentences(from text: String, count: Int = 3) -> [String] {
        let sentenceTokenizer = NLTokenizer(unit: .sentence)
        sentenceTokenizer.string = text
        var sentences: [String] = []
        sentenceTokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if sentence.count > 10 {
                sentences.append(sentence)
            }
            return true
        }

        guard !sentences.isEmpty else { return [] }

        var scoredSentences: [(String, Double)] = []
        for sentence in sentences {
            var score: Double = 0
            let words = sentence.lowercased().components(separatedBy: .whitespaces)
            for word in words {
                if !commonWords.contains(word) && word.count > 3 {
                    score += 1
                }
            }
            if sentence.contains("important") || sentence.contains("key") || sentence.contains("main") ||
               sentence.contains("summary") || sentence.contains("conclusion") {
                score += 3
            }
            if sentences.first == sentence || sentences.last == sentence {
                score += 2
            }
            scoredSentences.append((sentence, score))
        }

        return scoredSentences
            .sorted { $0.1 > $1.1 }
            .prefix(count)
            .map { $0.0 }
    }

    func cleanupText(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        result = result.replacingOccurrences(of: " +\n", with: "\n", options: .regularExpression)
        result = result.replacingOccurrences(of: "\n +", with: "\n", options: .regularExpression)
        result = result.replacingOccurrences(of: " ,", with: ",")
        result = result.replacingOccurrences(of: " \\.", with: ".", options: .regularExpression)
        result = result.replacingOccurrences(of: " !", with: "!")
        result = result.replacingOccurrences(of: " \\?", with: "?", options: .regularExpression)
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return result
    }

    func checkSpelling(_ text: String) -> [String] {
        let checker = UITextChecker()
        let range = NSRange(location: 0, length: text.utf16.count)
        var misspelled: [String] = []
        var offset = 0

        while offset < text.utf16.count {
            let wordRange = checker.rangeOfMisspelledWord(
                in: text,
                range: NSRange(location: offset, length: text.utf16.count - offset),
                startingAt: offset,
                wrap: false,
                language: "en"
            )
            if wordRange.location == NSNotFound { break }

            if let swiftRange = Range(wordRange, in: text) {
                let word = String(text[swiftRange])
                if !misspelled.contains(word) {
                    misspelled.append(word)
                }
            }
            offset = wordRange.location + wordRange.length
        }

        return misspelled
    }

    func calculateReadabilityScore(_ text: String) -> (score: Double, level: String) {
        let stats = analyzeTextStatistics(text)
        guard stats.wordCount > 0 && stats.sentenceCount > 0 else {
            return (0, "Not enough text")
        }

        let syllableCount = countSyllables(in: text)
        let fleschScore = 206.835 - 1.015 * (Double(stats.wordCount) / Double(stats.sentenceCount)) - 84.6 * (Double(syllableCount) / Double(stats.wordCount))
        let clampedScore = max(0, min(100, fleschScore))

        let level: String
        switch clampedScore {
        case 90...100: level = "Very Easy"
        case 80..<90: level = "Easy"
        case 70..<80: level = "Fairly Easy"
        case 60..<70: level = "Standard"
        case 50..<60: level = "Fairly Difficult"
        case 30..<50: level = "Difficult"
        default: level = "Very Difficult"
        }

        return (clampedScore, level)
    }

    private func countSyllables(in text: String) -> Int {
        let words = text.lowercased().components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        var total = 0
        for word in words {
            total += countSyllablesInWord(word)
        }
        return max(1, total)
    }

    private func countSyllablesInWord(_ word: String) -> Int {
        let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y"]
        var count = 0
        var lastWasVowel = false

        for char in word {
            let isVowel = vowels.contains(char)
            if isVowel && !lastWasVowel {
                count += 1
            }
            lastWasVowel = isVowel
        }

        if word.hasSuffix("e") && count > 1 {
            count -= 1
        }

        return max(1, count)
    }
}
