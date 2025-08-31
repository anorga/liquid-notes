import SwiftUI

struct LNHeader<Trailing: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let trailing: () -> Trailing
    
    init(title: String, subtitle: String? = nil, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 34, weight: .bold, design: .default))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let subtitle { Text(subtitle).font(.caption2).foregroundStyle(.secondary).transition(.opacity) }
            }
            Spacer(minLength: 12)
            trailing()
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 8)
        .background(Color.clear)
    }
}

#Preview {
    VStack(spacing:0) {
        LNHeader(title: "Notes", subtitle: "12 active • 3 archived") {
            Button(action: {}) { Image(systemName: "slider.horizontal.3") }
                .buttonStyle(.plain)
        }
        Spacer()
    }
}
