import Foundation
import UIKit
import ImageIO

enum RichTextArchiver {
    static func archive(_ attributed: NSAttributedString) -> Data? {
        // Use keyed archiver for compatibility
        do {
            return try attributed.data(from: NSRange(location: 0, length: attributed.length),
                                       documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd])
        } catch {
            return nil
        }
    }
    
    static func unarchive(_ data: Data) -> NSAttributedString? {
        // Attempt RTFD then fall back to plain
        if let attributed = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtfd], documentAttributes: nil) {
            return attributed
        }
        if let attributed = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
            return attributed
        }
        if let string = String(data: data, encoding: .utf8) {
            return NSAttributedString(string: string)
        }
        return nil
    }
}

// MARK: - Tokenization (strip binary attachment data)
extension RichTextArchiver {
    /// Token format [[ATTACH:<id>]] placed as its own line (with trailing newline) where an attachment occurs.
    static let attachmentTokenPrefix = "[[ATTACH:"
    static let attachmentTokenSuffix = "]]"

    /// Build a lightweight attributed string replacing attachments with textual tokens so the resulting RTF/UTF8 contains no binary image payloads.
    static func tokenizedAttributedString(from original: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString()
        original.enumerateAttributes(in: NSRange(location: 0, length: original.length)) { attrs, range, _ in
            if let att = attrs[.attachment] as? InteractiveTextAttachment, let id = att.attachmentID {
                // Ensure newline separation for layout consistency
                let token = "\n" + attachmentTokenPrefix + id + attachmentTokenSuffix + "\n"
                result.append(NSAttributedString(string: token, attributes: baseBodyAttributes()))
            } else {
                let substring = (original.string as NSString).substring(with: range)
                result.append(NSAttributedString(string: substring, attributes: normalizedAttributes(attrs)))
            }
        }
        return result
    }

    /// Rebuild rich text by scanning for tokens and replacing them with InteractiveTextAttachment stubs (image data loaded lazily if possible).
    static func rebuildFromTokens(note: Note, tokenized: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: tokenized)
        let fullRange = NSRange(location: 0, length: mutable.length)
    let pattern = "\\[\\[ATTACH:([A-Fa-f0-9-]+)\\]\\]" // hyphen at end, no escaping needed
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return tokenized }
        let matches = regex.matches(in: mutable.string, range: fullRange).reversed() // reverse for safe mutation
        for match in matches {
            guard match.numberOfRanges >= 2 else { continue }
            let idRange = match.range(at: 1)
            guard let swiftRange = Range(idRange, in: mutable.string) else { continue }
            let id = String(mutable.string[swiftRange])
            // Lookup file metadata
            guard let idx = note.fileAttachmentIDs.firstIndex(of: id) else { continue }
            let type = idx < note.fileAttachmentTypes.count ? note.fileAttachmentTypes[idx] : "image/jpeg"
            let fileName = idx < note.fileAttachmentNames.count ? note.fileAttachmentNames[idx] : ""
            var data: Data? = nil
            if let dir = AttachmentFileStore.noteDir(noteID: note.id), !fileName.isEmpty {
                let url = dir.appendingPathComponent(fileName)
                data = try? Data(contentsOf: url)
            }
            let newAttachment = InteractiveTextAttachment()
            newAttachment.note = note
            newAttachment.attachmentID = id
            if type == "image/gif", let d = data, let animated = decodeGIF(data: d) { newAttachment.image = animated; newAttachment.imageData = d }
            else if let d = data, let img = UIImage(data: d) { newAttachment.image = img; newAttachment.imageData = d }
            else { newAttachment.image = UIImage(systemName: "photo") }
            // Basic sizing (will be normalized by upgrade step later)
            if let size = newAttachment.image?.size { newAttachment.bounds = CGRect(x: 0, y: -5, width: min(size.width, 320), height: min(size.height, 220)) }
            let replacement = NSAttributedString(attachment: newAttachment)
            mutable.replaceCharacters(in: match.range, with: replacement)
        }
        return mutable
    }

    private static func normalizedAttributes(_ attrs: [NSAttributedString.Key: Any]) -> [NSAttributedString.Key: Any] {
        var newAttrs = attrs
        if newAttrs[.font] == nil { newAttrs[.font] = UIFont.systemFont(ofSize: 20, weight: .regular) }
        if newAttrs[.foregroundColor] == nil { newAttrs[.foregroundColor] = UIColor.label }
        newAttrs.removeValue(forKey: .attachment)
        return newAttrs
    }
    private static func baseBodyAttributes() -> [NSAttributedString.Key: Any] { [.font: UIFont.systemFont(ofSize: 20, weight: .regular), .foregroundColor: UIColor.label] }

    /// Produce RTF data (no binaries) from tokenized attributed string.
    static func archiveTokenized(_ tokenized: NSAttributedString) -> Data? {
        do {
            return try tokenized.data(from: NSRange(location: 0, length: tokenized.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        } catch { return tokenized.string.data(using: .utf8) }
    }

    static func computeHash(data: Data) -> String {
    var hash: UInt64 = 5381
    for b in data { hash = ((hash << 5) &+ hash) &+ UInt64(b) }
    return String(format: "%016llx", hash)
    }
}

// Local GIF decoder (avoids dependency on other file-level functions)
private func decodeGIF(data: Data) -> UIImage? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
    let count = CGImageSourceGetCount(source)
    guard count > 0 else { return nil }
    if count == 1 { return UIImage(data: data) }
    var images: [UIImage] = []
    var duration: Double = 0
    for i in 0..<count {
        guard let cg = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
        let frameDuration = gifFrameDuration(source: source, index: i)
        duration += frameDuration
        images.append(UIImage(cgImage: cg))
    }
    if duration <= 0 { duration = Double(count) * 0.08 }
    return UIImage.animatedImage(with: images, duration: duration)
}

private func gifFrameDuration(source: CGImageSource, index: Int) -> Double {
    guard let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
          let gifDict = props[kCGImagePropertyGIFDictionary] as? [CFString: Any] else { return 0.1 }
    let unclamped = gifDict[kCGImagePropertyGIFUnclampedDelayTime] as? Double
    let clamped = gifDict[kCGImagePropertyGIFDelayTime] as? Double
    let val = unclamped ?? clamped ?? 0.1
    return val < 0.02 ? 0.02 : val
}

struct AttachmentFileMeta {
    let id: String
    let type: String
    let fileURL: URL
    let thumbURL: URL?
}

enum AttachmentFileStore {
    private static let mediaQueue = DispatchQueue(label: "LNMediaIO", qos: .userInitiated)
    static func baseDirectory() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("Attachments", isDirectory: true)
    }
    
    static func ensureDirs() {
        if let dir = baseDirectory() {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
    
    static func noteDir(noteID: UUID) -> URL? {
        guard let base = baseDirectory() else { return nil }
        return base.appendingPathComponent(noteID.uuidString, isDirectory: true)
    }
    
    static func saveAttachment(note: Note, data: Data, type: String, preferredExt: String) -> (id: String, fileName: String, thumbName: String?)? {
        ensureDirs()
        guard let dir = noteDir(noteID: note.id) else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let id = UUID().uuidString
    let fileName = id + "." + preferredExt
        let fileURL = dir.appendingPathComponent(fileName)
        do { try data.write(to: fileURL, options: .atomic) } catch { return nil }
        // Thumbnail (only for images)
        var thumbName: String? = nil
        if type.hasPrefix("image"), let image = UIImage(data: data) {
            let target: CGFloat = 380
            let scale = min(1, target / max(image.size.width, image.size.height))
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            UIGraphicsBeginImageContextWithOptions(size, true, 1)
            image.draw(in: CGRect(origin: .zero, size: size))
            let thumb = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            if let t = thumb, let tData = t.jpegData(compressionQuality: 0.7) {
                let tn = id + "_thumb.jpg"
                do { try tData.write(to: dir.appendingPathComponent(tn), options: .atomic); thumbName = tn } catch {}
            }
        }
    note.addFileAttachment(id: id, type: type, fileName: fileName, thumbName: thumbName)
    return (id, fileName, thumbName)
    }

    /// Asynchronous, compressed save (reduces main-thread stalls when inserting large images).
    /// Completion returns (id, fileName, thumbName) on main thread when metadata has been appended to the note.
    static func saveAttachmentAsync(note: Note, data: Data, type: String, preferredExt: String, maxDimension: CGFloat = 2200, completion: ((String?, String?, String?) -> Void)? = nil) {
        ensureDirs()
        guard let dir = noteDir(noteID: note.id) else { completion?(nil,nil,nil); return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let id = UUID().uuidString
        let fileName = id + "." + preferredExt
        mediaQueue.async {
            var finalData = data
            if type.hasPrefix("image/"), preferredExt != "gif" { // compress non-gif images
                if let img = UIImage(data: data) {
                    let largest = max(img.size.width, img.size.height)
                    var targetImage = img
                    if largest > maxDimension {
                        let scale = maxDimension / largest
                        let newSize = CGSize(width: img.size.width * scale, height: img.size.height * scale)
                        UIGraphicsBeginImageContextWithOptions(newSize, true, 1)
                        img.draw(in: CGRect(origin: .zero, size: newSize))
                        targetImage = UIGraphicsGetImageFromCurrentImageContext() ?? img
                        UIGraphicsEndImageContext()
                    }
                    if let jpeg = targetImage.jpegData(compressionQuality: 0.8) { finalData = jpeg }
                }
            }
            let fileURL = dir.appendingPathComponent(fileName)
            do { try finalData.write(to: fileURL, options: .atomic) } catch { DispatchQueue.main.async { completion?(nil,nil,nil) }; return }
            var thumbName: String? = nil
            if type.hasPrefix("image"), let img = UIImage(data: finalData) {
                let target: CGFloat = 380
                let scale = min(1, target / max(img.size.width, img.size.height))
                let size = CGSize(width: img.size.width * scale, height: img.size.height * scale)
                UIGraphicsBeginImageContextWithOptions(size, true, 1)
                img.draw(in: CGRect(origin: .zero, size: size))
                let thumb = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                if let t = thumb, let tData = t.jpegData(compressionQuality: 0.7) {
                    let tn = id + "_thumb.jpg"
                    do { try tData.write(to: dir.appendingPathComponent(tn), options: .atomic); thumbName = tn } catch {}
                }
            }
            DispatchQueue.main.async {
                note.addFileAttachment(id: id, type: type, fileName: fileName, thumbName: thumbName)
                completion?(id, fileName, thumbName)
            }
        }
    }
}