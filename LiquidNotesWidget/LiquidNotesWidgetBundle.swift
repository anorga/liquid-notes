//
//  LiquidNotesWidgetBundle.swift
//  LiquidNotesWidget
//
//  Created by Christian Anorga on 8/17/25.
//

import WidgetKit
import SwiftUI

@main
struct LiquidNotesWidgetBundle: WidgetBundle {
    var body: some Widget {
        LiquidNotesWidget()
        QuickNoteControl()
        QuickTaskControl()
        TasksWidget()
    }
}
