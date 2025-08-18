//
//  LiquidNotesWidgetLiveActivity.swift
//  LiquidNotesWidget
//
//  Created by Christian Anorga on 8/17/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct LiquidNotesWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct LiquidNotesWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiquidNotesWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension LiquidNotesWidgetAttributes {
    fileprivate static var preview: LiquidNotesWidgetAttributes {
        LiquidNotesWidgetAttributes(name: "World")
    }
}

extension LiquidNotesWidgetAttributes.ContentState {
    fileprivate static var smiley: LiquidNotesWidgetAttributes.ContentState {
        LiquidNotesWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: LiquidNotesWidgetAttributes.ContentState {
         LiquidNotesWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: LiquidNotesWidgetAttributes.preview) {
   LiquidNotesWidgetLiveActivity()
} contentStates: {
    LiquidNotesWidgetAttributes.ContentState.smiley
    LiquidNotesWidgetAttributes.ContentState.starEyes
}
