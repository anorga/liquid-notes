import SwiftUI
import UIKit

struct ModernTextEditor: View {
    @Binding var attributedText: AttributedString
    let placeholder: String
    var onTextChanged: (() -> Void)?
    var onLinkTrigger: ((String, CGRect, UITextView) -> Void)?
    var onLinkCancel: (() -> Void)?
    
    @State private var textView: UITextView?
    @State private var isEditing = false
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if attributedText.description.isEmpty && !isEditing {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Start with your title...")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.tertiary)
                    
                    Text("Add content, tasks, and media inline")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .allowsHitTesting(false)
            }
            
            TextEditorWrapper(
                attributedText: $attributedText,
                onTextChanged: onTextChanged,
                onLinkTrigger: onLinkTrigger,
                onLinkCancel: onLinkCancel,
                onEditingChanged: { editing in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditing = editing
                    }
                },
                textViewBinding: $textView
            )
        }
    }
    
    func applyFormatting(_ format: TextFormat) {
        guard let textView = textView else { return }
        
        let selectedRange = textView.selectedRange
        let mutableAttributedText = NSMutableAttributedString(attributedText)
        
        switch format {
        case .title:
            applyStyle(to: mutableAttributedText, range: selectedRange, 
                      font: .systemFont(ofSize: 28, weight: .bold))
        case .heading:
            applyStyle(to: mutableAttributedText, range: selectedRange, 
                      font: .systemFont(ofSize: 22, weight: .semibold))
        case .body:
            applyStyle(to: mutableAttributedText, range: selectedRange, 
                      font: .systemFont(ofSize: 18, weight: .regular))
        case .bold:
            toggleBold(in: mutableAttributedText, range: selectedRange)
        case .italic:
            toggleItalic(in: mutableAttributedText, range: selectedRange)
        case .monospace:
            applyStyle(to: mutableAttributedText, range: selectedRange, 
                      font: .monospacedSystemFont(ofSize: 16, weight: .regular))
        case .bulletList:
            insertBulletPoint(at: selectedRange.location)
        case .numberedList:
            insertNumberedPoint(at: selectedRange.location)
        case .checkbox:
            insertCheckbox(at: selectedRange.location)
        }
        
        textView.attributedText = mutableAttributedText
        attributedText = AttributedString(mutableAttributedText)
        onTextChanged?()
    }
    
    private func applyStyle(to attributedText: NSMutableAttributedString, range: NSRange, font: UIFont) {
        if range.length > 0 {
            attributedText.addAttribute(.font, value: font, range: range)
        }
    }
    
    private func toggleBold(in attributedText: NSMutableAttributedString, range: NSRange) {
        guard range.length > 0 else { return }
        
        attributedText.enumerateAttribute(.font, in: range) { value, subRange, _ in
            if let currentFont = value as? UIFont {
                let newFont: UIFont
                if currentFont.fontDescriptor.symbolicTraits.contains(.traitBold) {
                    let traits = currentFont.fontDescriptor.symbolicTraits.subtracting(.traitBold)
                    let descriptor = currentFont.fontDescriptor.withSymbolicTraits(traits)
                    newFont = UIFont(descriptor: descriptor ?? currentFont.fontDescriptor, size: currentFont.pointSize)
                } else {
                    let descriptor = currentFont.fontDescriptor.withSymbolicTraits([currentFont.fontDescriptor.symbolicTraits, .traitBold])
                    newFont = UIFont(descriptor: descriptor ?? currentFont.fontDescriptor, size: currentFont.pointSize)
                }
                attributedText.addAttribute(.font, value: newFont, range: subRange)
            }
        }
    }
    
    private func toggleItalic(in attributedText: NSMutableAttributedString, range: NSRange) {
        guard range.length > 0 else { return }
        
        attributedText.enumerateAttribute(.font, in: range) { value, subRange, _ in
            if let currentFont = value as? UIFont {
                let newFont: UIFont
                if currentFont.fontDescriptor.symbolicTraits.contains(.traitItalic) {
                    let traits = currentFont.fontDescriptor.symbolicTraits.subtracting(.traitItalic)
                    let descriptor = currentFont.fontDescriptor.withSymbolicTraits(traits)
                    newFont = UIFont(descriptor: descriptor ?? currentFont.fontDescriptor, size: currentFont.pointSize)
                } else {
                    let descriptor = currentFont.fontDescriptor.withSymbolicTraits([currentFont.fontDescriptor.symbolicTraits, .traitItalic])
                    newFont = UIFont(descriptor: descriptor ?? currentFont.fontDescriptor, size: currentFont.pointSize)
                }
                attributedText.addAttribute(.font, value: newFont, range: subRange)
            }
        }
    }
    
    private func insertBulletPoint(at location: Int) {
        insertText("• ", at: location)
    }
    
    private func insertNumberedPoint(at location: Int) {
        insertText("1. ", at: location)
    }
    
    private func insertCheckbox(at location: Int) {
        insertText("\u{2610} ", at: location)
    }
    
    private func insertText(_ text: String, at location: Int) {
        guard let textView = textView else { return }
        
        let mutableAttributedText = NSMutableAttributedString(attributedString: textView.attributedText)
        let insertText = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 18),
                .foregroundColor: UIColor.label
            ]
        )
        
        mutableAttributedText.insert(insertText, at: location)
        textView.attributedText = mutableAttributedText
        attributedText = AttributedString(mutableAttributedText)
        
        // Move cursor after inserted text
        textView.selectedRange = NSRange(location: location + text.count, length: 0)
        onTextChanged?()
    }
    
    func insertImage(_ image: UIImage) {
        guard let textView = textView else { return }
        
        let textAttachment = NSTextAttachment()
        textAttachment.image = image
        
        // Scale image to fit
        let maxWidth: CGFloat = min(textView.frame.width - 40, 300)
        let scale = min(maxWidth / image.size.width, 200 / image.size.height)
        let scaledSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        textAttachment.bounds = CGRect(origin: .zero, size: scaledSize)
        
        let imageString = NSAttributedString(attachment: textAttachment)
        let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
        
        let selectedRange = textView.selectedRange
        
        // Insert with proper line breaks
        let prefix = selectedRange.location == 0 ? "" : "\n"
        let suffix = "\n"
        let fullInsert = NSMutableAttributedString(string: prefix)
        fullInsert.append(imageString)
        fullInsert.append(NSAttributedString(string: suffix))
        
        mutableText.insert(fullInsert, at: selectedRange.location)
        textView.attributedText = mutableText
        attributedText = AttributedString(mutableText)
        
        // Position cursor after image
        textView.selectedRange = NSRange(
            location: selectedRange.location + fullInsert.length,
            length: 0
        )
        
        onTextChanged?()
    }
}

enum TextFormat {
    case title, heading, body, bold, italic, monospace
    case bulletList, numberedList, checkbox
}

struct TextEditorWrapper: UIViewRepresentable {
    @Binding var attributedText: AttributedString
    let onTextChanged: (() -> Void)?
    let onLinkTrigger: ((String, CGRect, UITextView) -> Void)?
    let onLinkCancel: (() -> Void)?
    let onEditingChanged: (Bool) -> Void
    @Binding var textViewBinding: UITextView?
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.font = .systemFont(ofSize: 18)
        textView.textColor = .label
        textView.textContainerInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        
        // Enable smart features
        textView.smartInsertDeleteType = .yes
        textView.smartQuotesType = .yes
        textView.smartDashesType = .yes
        textView.autocorrectionType = .yes
        textView.spellCheckingType = .yes
        
        // Writing tools will be automatically available when supported
        
        textView.allowsEditingTextAttributes = true
        textView.isScrollEnabled = true
        textView.keyboardDismissMode = .interactive
        
        // Set up drop interaction
        let dropInteraction = UIDropInteraction(delegate: context.coordinator)
        textView.addInteraction(dropInteraction)
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        // Update text if different
        let currentAttributedString = NSAttributedString(attributedText)
        if !uiView.attributedText.isEqual(to: currentAttributedString) {
            uiView.attributedText = currentAttributedString
        }
        
        // Update binding
        DispatchQueue.main.async {
            textViewBinding = uiView
        }
        
        context.coordinator.parent = self
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate, UIDropInteractionDelegate {
        var parent: TextEditorWrapper
        
        init(_ parent: TextEditorWrapper) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.attributedText = AttributedString(textView.attributedText)
            parent.onTextChanged?()
            detectLinkTrigger(in: textView)
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.onEditingChanged(true)
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            parent.onEditingChanged(false)
        }
        
        private func detectLinkTrigger(in textView: UITextView) {
            let cursorLocation = textView.selectedRange.location
            guard cursorLocation <= textView.text.count else {
                parent.onLinkCancel?()
                return
            }
            
            let text = textView.text as NSString
            var start = cursorLocation
            
            // Find start of current word
            while start > 0 {
                let char = text.character(at: start - 1)
                let character = Character(UnicodeScalar(char)!)
                if character == "\n" || character.isWhitespace { break }
                start -= 1
            }
            
            let length = cursorLocation - start
            guard length >= 2 else {
                parent.onLinkCancel?()
                return
            }
            
            let token = text.substring(with: NSRange(location: start, length: length))
            
            if token.hasPrefix("[[") {
                let query = String(token.dropFirst(2))
                if let caretRect = getCaretRect(textView) {
                    parent.onLinkTrigger?(query, caretRect, textView)
                }
            } else {
                parent.onLinkCancel?()
            }
        }
        
        private func getCaretRect(_ textView: UITextView) -> CGRect? {
            guard let range = textView.selectedTextRange else { return nil }
            let rect = textView.caretRect(for: range.start)
            return textView.convert(rect, to: textView.superview)
        }
        
        // MARK: - Drop Delegate
        
        func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
            return session.hasItemsConforming(toTypeIdentifiers: ["public.image"])
        }
        
        func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
            return UIDropProposal(operation: .copy)
        }
        
        func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
            for item in session.items {
                if item.itemProvider.hasItemConformingToTypeIdentifier("public.image") {
                    item.itemProvider.loadDataRepresentation(forTypeIdentifier: "public.image") { data, _ in
                        if let data = data, let image = UIImage(data: data) {
                            DispatchQueue.main.async {
                                if let modernEditor = interaction.view?.superview as? UIView,
                                   let hostingView = self.findModernTextEditor(in: modernEditor) {
                                    hostingView.insertImage(image)
                                }
                            }
                        }
                    }
                }
            }
        }
        
        private func findModernTextEditor(in view: UIView) -> ModernTextEditor? {
            // This is a simplified approach - in a real implementation,
            // you'd need a proper way to communicate back to the ModernTextEditor
            return nil
        }
    }
}

