import SwiftUI
import UIKit

struct UnifiedTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var attributedText: NSAttributedString
    var onTextChanged: (() -> Void)?
    var onLinkTrigger: ((String, CGRect, UITextView) -> Void)?
    var onLinkCancel: (() -> Void)?
    let geometry: GeometryProxy
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.systemFont(ofSize: 18, weight: .regular)
        textView.backgroundColor = .clear
        textView.textColor = .label
        textView.textContainerInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .default
        textView.allowsEditingTextAttributes = true
        textView.isScrollEnabled = true
        textView.keyboardDismissMode = .interactive
        textView.contentInsetAdjustmentBehavior = .never
        
        textView.smartInsertDeleteType = .yes
        textView.smartQuotesType = .yes
        textView.smartDashesType = .yes
        textView.spellCheckingType = .yes
        
        textView.typingAttributes = [
            .font: UIFont.systemFont(ofSize: 18, weight: .regular),
            .foregroundColor: UIColor.label
        ]
        
        if #available(iOS 16.0, *) {
            textView.isFindInteractionEnabled = true
        }
        
        if #available(iOS 17.0, *) {
            textView.borderStyle = .none
        }
        
        textView.textDragInteraction?.isEnabled = true
        
        let dropInteraction = UIDropInteraction(delegate: context.coordinator)
        textView.addInteraction(dropInteraction)
        
        setupTextViewForUnifiedEditing(textView)
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        
        uiView.textColor = .label
        uiView.font = UIFont.systemFont(ofSize: 18, weight: .regular)
        
        context.coordinator.parent = self
    }
    
    private func setupTextViewForUnifiedEditing(_ textView: UITextView) {
        textView.isEditable = true
        textView.isSelectable = true
        textView.dataDetectorTypes = []
        
        textView.layer.cornerRadius = 0
        textView.layer.borderWidth = 0
        
        if text.isEmpty {
            textView.text = ""
            addPlaceholderText(to: textView)
        }
    }
    
    private func addPlaceholderText(to textView: UITextView) {
        let placeholderText = "Start with your title...\n\nAdd content, tasks, and media inline"
        textView.text = placeholderText
        textView.textColor = .placeholderText
        textView.selectedRange = NSRange(location: 0, length: 0)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate, UIDropInteractionDelegate {
        var parent: UnifiedTextEditor
        
        init(_ parent: UnifiedTextEditor) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            if textView.textColor == .placeholderText {
                textView.text = ""
                textView.textColor = .label
            }
            
            textView.textColor = .label
            textView.font = UIFont.systemFont(ofSize: 18, weight: .regular)
            
            let currentRange = textView.selectedRange
            applySmartFormatting(to: textView)
            textView.selectedRange = currentRange
            
            DispatchQueue.main.async {
                self.parent.text = textView.text
                self.parent.attributedText = textView.attributedText
                self.parent.onTextChanged?()
                self.detectLinkTrigger(in: textView)
            }
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            if textView.textColor == .placeholderText {
                textView.text = ""
                textView.textColor = .label
            }
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            if textView.text.isEmpty {
                parent.addPlaceholderText(to: textView)
            }
        }
        
        private func applySmartFormatting(to textView: UITextView) {
            let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
            let range = NSRange(location: 0, length: mutableText.length)
            
            mutableText.addAttributes([
                .font: UIFont.systemFont(ofSize: 18, weight: .regular),
                .foregroundColor: UIColor.label
            ], range: range)
            
            formatFirstLineAsTitle(mutableText)
            formatChecklistItems(mutableText)
            formatLinks(mutableText)
            
            textView.attributedText = mutableText
        }
        
        private func formatFirstLineAsTitle(_ mutableText: NSMutableAttributedString) {
            let text = mutableText.string
            guard let firstLineRange = text.range(of: "^.*$", options: .regularExpression) else { return }
            
            let nsRange = NSRange(firstLineRange, in: text)
            mutableText.addAttributes([
                .font: UIFont.systemFont(ofSize: 28, weight: .bold),
                .foregroundColor: UIColor.label
            ], range: nsRange)
        }
        
        private func formatChecklistItems(_ mutableText: NSMutableAttributedString) {
            let text = mutableText.string
            let pattern = "^[\u{2610}\u{2611}] "
            
            let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
            regex?.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: text.count)) { match, _, _ in
                guard let range = match?.range else { return }
                mutableText.addAttributes([
                    .font: UIFont.systemFont(ofSize: 16, weight: .medium),
                    .foregroundColor: UIColor.systemBlue
                ], range: range)
            }
        }
        
        private func formatLinks(_ mutableText: NSMutableAttributedString) {
            let text = mutableText.string
            let pattern = "\\[\\[([^\\]]+)\\]\\]"
            
            let regex = try? NSRegularExpression(pattern: pattern, options: [])
            regex?.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: text.count)) { match, _, _ in
                guard let range = match?.range else { return }
                mutableText.addAttributes([
                    .foregroundColor: UIColor.systemBlue,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ], range: range)
            }
        }
        
        private func detectLinkTrigger(in textView: UITextView) {
            let cursorLocation = textView.selectedRange.location
            guard cursorLocation <= textView.text.count else { parent.onLinkCancel?(); return }
            let nsText = textView.text as NSString
            
            var start = cursorLocation
            while start > 0 {
                let char = nsText.character(at: start - 1)
                if Character(UnicodeScalar(char)!) == "\n" || Character(UnicodeScalar(char)!).isWhitespace { break }
                start -= 1
            }
            let length = cursorLocation - start
            guard length >= 2 else { parent.onLinkCancel?(); return }
            let token = nsText.substring(with: NSRange(location: start, length: length))
            
            if token.hasPrefix("[[") {
                let query = String(token.dropFirst(2))
                if let caret = caretRect(textView) {
                    parent.onLinkTrigger?(query, caret, textView)
                }
            } else {
                parent.onLinkCancel?()
            }
        }
        
        private func caretRect(_ textView: UITextView) -> CGRect? {
            guard let range = textView.selectedTextRange else { return nil }
            let rect = textView.caretRect(for: range.start)
            let converted = textView.convert(rect, to: textView.superview)
            return converted
        }
        
        func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
            return session.hasItemsConforming(toTypeIdentifiers: ["public.image", "com.compuserve.gif"])
        }
        
        func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
            return UIDropProposal(operation: .copy)
        }
        
        func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
            for item in session.items {
                if item.itemProvider.hasItemConformingToTypeIdentifier("public.image") {
                    item.itemProvider.loadDataRepresentation(forTypeIdentifier: "public.image") { data, error in
                        if let data = data, let image = UIImage(data: data) {
                            DispatchQueue.main.async {
                                self.insertImage(image, into: interaction.view as! UITextView)
                            }
                        }
                    }
                }
            }
        }
        
        private func insertImage(_ image: UIImage, into textView: UITextView) {
            let textAttachment = NSTextAttachment()
            textAttachment.image = image
            
            let imageSize = image.size
            let maxWidth: CGFloat = min(textView.frame.width - 40, 300)
            let ratio = min(maxWidth / imageSize.width, 200 / imageSize.height)
            let newWidth = imageSize.width * ratio
            let newHeight = imageSize.height * ratio
            
            textAttachment.bounds = CGRect(x: 0, y: -5, width: newWidth, height: newHeight)
            
            let imageString = NSAttributedString(attachment: textAttachment)
            let mutableString = NSMutableAttributedString(attributedString: textView.attributedText)
            
            let selectedRange = textView.selectedRange
            let newlineBeforeImage = NSAttributedString(string: "\n")
            let newlineAfterImage = NSAttributedString(string: "\n")
            
            mutableString.insert(newlineAfterImage, at: selectedRange.location)
            mutableString.insert(imageString, at: selectedRange.location)
            mutableString.insert(newlineBeforeImage, at: selectedRange.location)
            
            textView.attributedText = mutableString
            
            DispatchQueue.main.async {
                self.parent.attributedText = mutableString
                self.parent.text = textView.text
            }
            
            textView.selectedRange = NSRange(location: selectedRange.location + 3, length: 0)
        }
    }
}