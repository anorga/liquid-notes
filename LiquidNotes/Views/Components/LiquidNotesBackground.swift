//
//  LiquidNotesBackground.swift
//  LiquidNotes
//
//  Created by Christian Anorga on 8/19/25.
//

import SwiftUI

// MARK: - iOS 26 Liquid Glass Optimized Background Component

struct LiquidNotesBackground: View {
    var body: some View {
        // iOS 26: Perfect adaptive background for Liquid Glass
        Color(.systemGray6)
            .ignoresSafeArea()
    }
}

#Preview {
    LiquidNotesBackground()
}