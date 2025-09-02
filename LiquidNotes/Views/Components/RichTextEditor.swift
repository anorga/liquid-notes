//
//  RichTextEditor.swift
//  LiquidNotes
//
//  Created by Christian Anorga on 8/21/25.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct RichTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var attributedText: NSAttributedString
    let placeholder: String
    var onTextChanged: (() -> Void)? = nil // iOS 26: Direct callback for changes
    // Autocomplete support
    var onLinkTrigger: ((String, CGRect, UITextView) -> Void)? = nil
    var onLinkCancel: (() -> Void)? = nil
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.systemFont(ofSize: 17)
        textView.backgroundColor = .clear
        textView.textColor = .label // iOS 26: Adaptive color for dark/light mode
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .default
        textView.allowsEditingTextAttributes = true
        textView.isScrollEnabled = true
        
        // Enable native keyboard features
        textView.smartInsertDeleteType = .yes
        textView.smartQuotesType = .yes
        textView.smartDashesType = .yes
        
        // iOS 26: Enhanced typing attributes with adaptive colors
        textView.typingAttributes = [
            .font: UIFont.systemFont(ofSize: 17),
            .foregroundColor: UIColor.label // Adaptive text color for dark/light mode
        ]
        
        // iOS 26: Force adaptive color mode support
        if #available(iOS 26.0, *) {
            textView.overrideUserInterfaceStyle = .unspecified // Allow automatic adaptation
        }
        
        // Allow text formatting from keyboard (Bold, Italic, etc.)
        if #available(iOS 16.0, *) {
            textView.isFindInteractionEnabled = true
        }
        
        // Support for stickers and GIFs from keyboard - iOS 26 approach
        textView.textDragInteraction?.isEnabled = true
        
        // Enable drop interaction for images and GIFs
        let dropInteraction = UIDropInteraction(delegate: context.coordinator)
        textView.addInteraction(dropInteraction)
        
        // Enable text attachment editing and moving for iOS 26
        textView.isEditable = true
        textView.isSelectable = true
        textView.dataDetectorTypes = []
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        // iOS 26: Normalize attributed text to ensure consistent font and color
        if uiView.attributedText != attributedText {
            let normalizedAttributedText = normalizeAttributedText(attributedText)
            uiView.attributedText = normalizedAttributedText
        }
        
        // iOS 26: Ensure proper text color adaptation for dark/light mode
        if attributedText.length == 0 {
            uiView.text = placeholder
            uiView.textColor = .placeholderText
        } else {
            if uiView.textColor == .placeholderText {
                uiView.text = ""
            }
            // Always enforce adaptive text color and consistent font for dark/light mode
            uiView.textColor = .label
            uiView.font = UIFont.systemFont(ofSize: 17) // Ensure consistent font size
            uiView.typingAttributes = [
                .font: UIFont.systemFont(ofSize: 17),
                .foregroundColor: UIColor.label // iOS 26: Adaptive text color
            ]
        }
    }
    
    // iOS 26: Normalize attributed text to maintain consistent formatting
    private func normalizeAttributedText(_ attributedText: NSAttributedString) -> NSAttributedString {
        return Coordinator.normalizeAttributedText(attributedText)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate, UIDropInteractionDelegate {
        let parent: RichTextEditor
        
        init(_ parent: RichTextEditor) {
            self.parent = parent
        }
        
    func textViewDidChange(_ textView: UITextView) {
            // Handle placeholder logic
            if textView.textColor == .placeholderText {
                textView.text = ""
                textView.textColor = .label
            }
            
            // iOS 26: Ensure text color and font stay consistent during typing
            if textView.textColor != .placeholderText {
                textView.textColor = .label
                textView.font = UIFont.systemFont(ofSize: 17) // Maintain consistent font size
                textView.typingAttributes = [
                    .font: UIFont.systemFont(ofSize: 17),
                    .foregroundColor: UIColor.label
                ]
                
                // iOS 26: Normalize any new attributed text to maintain consistency
                if textView.attributedText.length > 0 {
                    let normalizedText = Self.normalizeAttributedText(textView.attributedText)
                    if !normalizedText.isEqual(to: textView.attributedText) {
                        textView.attributedText = normalizedText
                    }
                }
            }
            
            // Update parent bindings on main thread
            DispatchQueue.main.async {
                self.parent.text = textView.text
                self.parent.attributedText = textView.attributedText
                // iOS 26: Trigger direct callback to ensure change detection
                self.parent.onTextChanged?()
                self.detectLinkTrigger(in: textView)
            }
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            if textView.textColor == .placeholderText {
                textView.text = ""
                textView.textColor = .label
            }
            // iOS 26: Ensure adaptive typing attributes when editing begins
            textView.typingAttributes = [
                .font: UIFont.systemFont(ofSize: 17),
                .foregroundColor: UIColor.label
            ]
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            if textView.text.isEmpty {
                textView.text = parent.placeholder
                textView.textColor = .placeholderText
            }
        }
        
        // iOS 26 compatible text attachment handling
        func textView(_ textView: UITextView, primaryActionFor textItem: UITextItem, defaultAction: UIAction) -> UIAction? {
            return defaultAction
        }
        
        // Drop interaction delegate methods for iOS 26
        func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
            return session.hasItemsConforming(toTypeIdentifiers: [UTType.image.identifier, UTType.gif.identifier])
        }
        
        func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
            return UIDropProposal(operation: .copy)
        }
        
        func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
            for item in session.items {
                if item.itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    item.itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                        if let data = data, let image = UIImage(data: data) {
                            DispatchQueue.main.async {
                                self.insertImage(image, into: interaction.view as! UITextView)
                            }
                        }
                    }
                } else if item.itemProvider.hasItemConformingToTypeIdentifier(UTType.gif.identifier) {
                    item.itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.gif.identifier) { data, error in
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
            
            // Resize image to fit text with proper padding
            let imageSize = image.size
            let maxWidth: CGFloat = min(textView.frame.width - 32, 200) // Max 200pt width
            let ratio = min(maxWidth / imageSize.width, 150 / imageSize.height) // Max 150pt height
            let newWidth = imageSize.width * ratio
            let newHeight = imageSize.height * ratio
            
            textAttachment.bounds = CGRect(x: 0, y: -5, width: newWidth, height: newHeight)
            
            // Create attributed string with proper paragraph spacing
            let imageString = NSAttributedString(attachment: textAttachment)
            let mutableString = NSMutableAttributedString(attributedString: textView.attributedText)
            
            // Insert at cursor position with line breaks for proper text flow
            let selectedRange = textView.selectedRange
            let newlineBeforeImage = NSAttributedString(string: "\n")
            let newlineAfterImage = NSAttributedString(string: "\n")
            
            // Insert with proper spacing
            mutableString.insert(newlineAfterImage, at: selectedRange.location)
            mutableString.insert(imageString, at: selectedRange.location)
            mutableString.insert(newlineBeforeImage, at: selectedRange.location)
            
            textView.attributedText = mutableString
            
            // Update parent bindings
            DispatchQueue.main.async {
                self.parent.attributedText = mutableString
                self.parent.text = textView.text
            }
            
            // Move cursor after inserted content
            textView.selectedRange = NSRange(location: selectedRange.location + 3, length: 0)
        }
        
        // iOS 26: Static method to normalize attributed text for consistent formatting
        static func normalizeAttributedText(_ attributedText: NSAttributedString) -> NSAttributedString {
            let mutableAttributedText = NSMutableAttributedString(attributedString: attributedText)
            let range = NSRange(location: 0, length: mutableAttributedText.length)
            
            // Apply consistent font and adaptive color throughout the text
            mutableAttributedText.addAttributes([
                .font: UIFont.systemFont(ofSize: 17),
                .foregroundColor: UIColor.label
            ], range: range)
            
            return mutableAttributedText
        }

        private func detectLinkTrigger(in textView: UITextView) {
            let cursorLocation = textView.selectedRange.location
            guard cursorLocation <= textView.text.count else { parent.onLinkCancel?(); return }
            let nsText = textView.text as NSString
            // Find range of current token (back to whitespace or newline)
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
                // Get caret rect
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
    }
}

// Font picker for custom fonts
struct FontPicker: View {
    @Binding var selectedFont: String
    @Binding var fontSize: CGFloat
    @State private var showingFontPicker = false
    
    let availableFonts = [
        "System": UIFont.systemFont(ofSize: 17).fontName,
        "Helvetica": "Helvetica",
        "Times": "Times New Roman",
        "Courier": "Courier New",
        "Georgia": "Georgia",
        "Verdana": "Verdana",
        "Trebuchet": "Trebuchet MS",
        "Impact": "Impact",
        "Comic Sans": "Comic Sans MS"
    ]
    
    var body: some View {
        HStack {
            Button(action: {
                showingFontPicker = true
            }) {
                HStack {
                    Image(systemName: "textformat")
                    Text(fontDisplayName)
                        .font(.custom(selectedFont, size: 14))
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .foregroundColor(.blue)
            }
            
            Spacer()
            
            // Font size controls
            HStack {
                Button(action: {
                    if fontSize > 12 {
                        fontSize -= 1
                        HapticManager.shared.buttonTapped()
                    }
                }) {
                    Image(systemName: "minus.circle")
                        .foregroundColor(.blue)
                }
                
                Text("\(Int(fontSize))")
                    .font(.caption)
                    .frame(width: 30)
                
                Button(action: {
                    if fontSize < 24 {
                        fontSize += 1
                        HapticManager.shared.buttonTapped()
                    }
                }) {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .actionSheet(isPresented: $showingFontPicker) {
            ActionSheet(
                title: Text("Choose Font"),
                buttons: availableFonts.map { fontName, fontFamily in
                    .default(Text(fontName).font(.custom(fontFamily, size: 16))) {
                        selectedFont = fontFamily
                        HapticManager.shared.buttonTapped()
                    }
                } + [.cancel()]
            )
        }
    }
    
    private var fontDisplayName: String {
        availableFonts.first { $0.value == selectedFont }?.key ?? "System"
    }
}

