import SwiftUI

struct TextEditorView: View {
    @Binding var attributedText: AttributedString
    @Binding var hasChanges: Bool
    @Binding var textEditor: ModernTextEditor?
    @Binding var showingFormattingBar: Bool
    @Binding var linkQuery: String
    @Binding var linkAnchorRect: CGRect
    @Binding var showLinkOverlay: Bool
    @Binding var activeTextView: UITextView?
    
    let onTextChanged: () -> Void
    
    var body: some View {
        ModernTextEditor(
            attributedText: $attributedText,
            placeholder: "Start with your title...",
            onTextChanged: { 
                hasChanges = true 
                onTextChanged()
            },
            onLinkTrigger: { query, rect, tv in
                linkQuery = query
                linkAnchorRect = rect
                activeTextView = tv
                showLinkOverlay = true
            },
            onLinkCancel: { showLinkOverlay = false }
        )
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showingFormattingBar = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showingFormattingBar = false
            }
        }
    }
}