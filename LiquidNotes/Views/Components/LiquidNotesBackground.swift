//
//  LiquidNotesBackground.swift
//  LiquidNotes
//
//  Created by Christian Anorga on 8/19/25.
//

import SwiftUI

struct LiquidNotesBackground: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Color(red: 0.0, green: 0.4, blue: 0.8).opacity(0.8), location: 0.0),
                .init(color: Color.orange.opacity(0.6), location: 0.5),
                .init(color: Color(red: 0.0, green: 0.35, blue: 0.7).opacity(0.85), location: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

#Preview {
    LiquidNotesBackground()
}