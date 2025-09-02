import Foundation
import UIKit

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

struct AttachmentFileMeta {
    let id: String
    let type: String
    let fileURL: URL
    let thumbURL: URL?
}

enum AttachmentFileStore {
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
    
    static func saveAttachment(note: Note, data: Data, type: String, preferredExt: String) -> (fileName: String, thumbName: String?)? {
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
        return (fileName, thumbName)
    }
}