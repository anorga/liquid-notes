import SwiftUI
import UIKit
import PhotosUI

struct FormattingToolbar: View {
    @Binding var activeTextView: UITextView?
    let onPhotoSelect: (PhotosPickerItem) -> Void
    let onGifSelect: () -> Void
    
    @State private var selectedPhoto: PhotosPickerItem?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                formatButton(title: "Title", icon: "textformat.size.larger") {
                    applyFormat(.title)
                }
                
                formatButton(title: "Heading", icon: "textformat") {
                    applyFormat(.heading)
                }
                
                formatButton(title: "Body", icon: "textformat.abc") {
                    applyFormat(.body)
                }
                
                Divider()
                    .frame(height: 20)
                
                formatButton(title: "Bold", icon: "bold") {
                    toggleFormat(.bold)
                }
                
                formatButton(title: "Italic", icon: "italic") {
                    toggleFormat(.italic)
                }
                
                formatButton(title: "Code", icon: "chevron.left.forwardslash.chevron.right") {
                    applyFormat(.monospace)
                }
                
                Divider()
                    .frame(height: 20)
                
                formatButton(title: "• List", icon: "list.bullet") {
                    insertBulletList()
                }
                
                formatButton(title: "1. List", icon: "list.number") {
                    insertNumberedList()
                }
                
                formatButton(title: "Quote", icon: "text.quote") {
                    insertBlockQuote()
                }
                
                formatButton(title: "Task", icon: "checklist") {
                    insertChecklistItem()
                }
                
                Divider()
                    .frame(height: 20)
                
                PhotosPicker(selection: $selectedPhoto, matching: .any(of: [.images, .livePhotos])) {
                    formatButton(title: "Photo", icon: "photo") { }
                }
                
                formatButton(title: "GIF", icon: "face.smiling") {
                    onGifSelect()
                }
                
                formatButton(title: "Link", icon: "link") {
                    insertLink()
                }
                
                formatButton(title: "Table", icon: "tablecells") {
                    insertTable()
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 50)
        .background(.ultraThinMaterial)
        .onChange(of: selectedPhoto) { _, newPhoto in
            if let photo = newPhoto {
                onPhotoSelect(photo)
                selectedPhoto = nil
            }
        }
    }
    
    @ViewBuilder
    private func formatButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.caption2)
            }
            .foregroundStyle(.primary)
            .frame(minWidth: 44)
        }
    }
    
    private enum TextStyle {
        case title, heading, body, monospace
    }
    
    private enum ToggleFormat {
        case bold, italic
    }
    
    private func applyFormat(_ style: TextStyle) {
        guard let textView = activeTextView else { return }
        
        let selectedRange = textView.selectedRange
        let mutableAttributedText = NSMutableAttributedString(attributedString: textView.attributedText)
        
        let font: UIFont
        switch style {
        case .title:
            font = UIFont.systemFont(ofSize: 28, weight: .bold)
        case .heading:
            font = UIFont.systemFont(ofSize: 22, weight: .semibold)
        case .body:
            font = UIFont.systemFont(ofSize: 18, weight: .regular)
        case .monospace:
            font = UIFont.monospacedSystemFont(ofSize: 16, weight: .regular)
        }
        
        if selectedRange.length > 0 {
            mutableAttributedText.addAttribute(.font, value: font, range: selectedRange)
        } else {
            textView.typingAttributes[.font] = font
        }
        
        textView.attributedText = mutableAttributedText
    }
    
    private func toggleFormat(_ format: ToggleFormat) {
        guard let textView = activeTextView else { return }
        
        let selectedRange = textView.selectedRange
        let mutableAttributedText = NSMutableAttributedString(attributedString: textView.attributedText)
        
        if selectedRange.length > 0 {
            mutableAttributedText.enumerateAttribute(.font, in: selectedRange) { value, range, _ in
                if let currentFont = value as? UIFont {
                    var newFont: UIFont
                    
                    switch format {
                    case .bold:
                        if currentFont.fontDescriptor.symbolicTraits.contains(.traitBold) {
                            newFont = UIFont.systemFont(ofSize: currentFont.pointSize, weight: .regular)
                        } else {
                            newFont = UIFont.systemFont(ofSize: currentFont.pointSize, weight: .bold)
                        }
                    case .italic:
                        if currentFont.fontDescriptor.symbolicTraits.contains(.traitItalic) {
                            newFont = currentFont.withoutItalic()
                        } else {
                            newFont = currentFont.withItalic()
                        }
                    }
                    
                    mutableAttributedText.addAttribute(.font, value: newFont, range: range)
                }
            }
            
            textView.attributedText = mutableAttributedText
        }
    }
    
    private func insertBulletList() {
        insertAtCursor("• ")
    }
    
    private func insertNumberedList() {
        insertAtCursor("1. ")
    }
    
    private func insertBlockQuote() {
        insertAtCursor("> ")
    }
    
    private func insertChecklistItem() {
        insertAtCursor("\u{2610} ")
    }
    
    private func insertLink() {
        insertAtCursor("[[]]")
        if let textView = activeTextView {
            let newPosition = textView.selectedRange.location - 2
            textView.selectedRange = NSRange(location: newPosition, length: 0)
        }
    }
    
    private func insertTable() {
        let table = """
        | Header 1 | Header 2 | Header 3 |
        |----------|----------|----------|
        | Cell 1   | Cell 2   | Cell 3   |
        | Cell 4   | Cell 5   | Cell 6   |
        
        """
        insertAtCursor(table)
    }
    
    private func insertAtCursor(_ text: String) {
        guard let textView = activeTextView else { return }
        
        let selectedRange = textView.selectedRange
        let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
        let insertText = NSAttributedString(string: text, attributes: textView.typingAttributes)
        
        mutableText.insert(insertText, at: selectedRange.location)
        textView.attributedText = mutableText
        textView.selectedRange = NSRange(location: selectedRange.location + text.count, length: 0)
    }
}

extension UIFont {
    func withItalic() -> UIFont {
        let descriptor = fontDescriptor.withSymbolicTraits([fontDescriptor.symbolicTraits, .traitItalic])
        return UIFont(descriptor: descriptor ?? fontDescriptor, size: pointSize)
    }
    
    func withoutItalic() -> UIFont {
        let traits = fontDescriptor.symbolicTraits
        let newTraits = traits.subtracting(.traitItalic)
        let descriptor = fontDescriptor.withSymbolicTraits(newTraits)
        return UIFont(descriptor: descriptor ?? fontDescriptor, size: pointSize)
    }
}