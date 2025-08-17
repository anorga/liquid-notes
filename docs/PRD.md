# Liquid Notes - Technical Product Requirements Document

## Project Overview

**App Name**: Liquid Notes  
**Bundle Identifier**: `FluidLabs.LiquidNotes`  
**Platform**: iOS 17.0+, iPadOS 17.0+  
**Development Language**: Swift 5.9+  
**UI Framework**: SwiftUI 5.0+  
**Target Release**: Q2 2025  

### Core Value Proposition
The first sticky notes app to fully implement Apple's Liquid Glass design language, providing a premium note-taking experience with translucent, interactive glass materials that respond to device movement and content.

## Technical Architecture

### Core Technologies
- **UI Framework**: SwiftUI with Liquid Glass APIs
- **Data Persistence**: SwiftData + CloudKit
- **Graphics**: Core Animation, Metal Performance Shaders
- **Device Integration**: Core Motion, WidgetKit, Shortcuts
- **Cloud Services**: CloudKit for seamless sync

### Project Structure
```
LiquidNotes/
├── App/
│   ├── LiquidNotesApp.swift
│   ├── ContentView.swift
│   └── Info.plist
├── Models/
│   ├── Note.swift
│   ├── NoteCategory.swift
│   ├── GlassTheme.swift
│   └── DataContainer.swift
├── Views/
│   ├── NoteViews/
│   │   ├── NoteCardView.swift
│   │   ├── NoteEditorView.swift
│   │   └── NoteListView.swift
│   ├── GlassEffects/
│   │   ├── LiquidGlassView.swift
│   │   ├── GlassBackground.swift
│   │   └── MotionResponsiveGlass.swift
│   └── Components/
│       ├── FloatingButton.swift
│       ├── GlassTextField.swift
│       └── ContextualToolbar.swift
├── ViewModels/
│   ├── NotesViewModel.swift
│   ├── GlassEffectsViewModel.swift
│   └── CloudSyncViewModel.swift
├── Utilities/
│   ├── HapticManager.swift
│   ├── MotionManager.swift
│   └── ColorThemeManager.swift
├── Extensions/
│   ├── Color+Themes.swift
│   ├── View+GlassEffect.swift
│   └── UIDevice+Capabilities.swift
└── Resources/
    ├── Assets.xcassets
    └── Localizable.strings
```

## Data Models

### Note Model (SwiftData)
```swift
import SwiftData
import Foundation

@Model
final class Note {
    var id: UUID
    var title: String
    var content: String
    var createdDate: Date
    var modifiedDate: Date
    var glassThemeID: String
    var positionX: Float
    var positionY: Float
    var zIndex: Int
    var isArchived: Bool
    var isPinned: Bool
    var tags: [String]
    
    // Relationship
    var category: NoteCategory?
    
    init(title: String = "", content: String = "", glassThemeID: String = "clear") {
        self.id = UUID()
        self.title = title
        self.content = content
        self.createdDate = Date()
        self.modifiedDate = Date()
        self.glassThemeID = glassThemeID
        self.positionX = 0
        self.positionY = 0
        self.zIndex = 0
        self.isArchived = false
        self.isPinned = false
        self.tags = []
    }
}

@Model
final class NoteCategory {
    var id: UUID
    var name: String
    var color: String
    var createdDate: Date
    
    // Relationship
    @Relationship(deleteRule: .cascade, inverse: \Note.category)
    var notes: [Note]
    
    init(name: String, color: String = "blue") {
        self.id = UUID()
        self.name = name
        self.color = color
        self.createdDate = Date()
        self.notes = []
    }
}
```

### Glass Theme Model
```swift
struct GlassTheme: Codable, Identifiable {
    let id: String
    let name: String
    let baseOpacity: Double
    let blurRadius: Double
    let tintColor: Color
    let highlightIntensity: Double
    let reflectionEnabled: Bool
    let motionResponseIntensity: Double
    let isPremium: Bool
    
    static let defaultThemes = [
        GlassTheme(id: "clear", name: "Clear Crystal", baseOpacity: 0.1, ...),
        GlassTheme(id: "frosted", name: "Frosted Glass", baseOpacity: 0.3, ...),
        GlassTheme(id: "tinted", name: "Ocean Tint", baseOpacity: 0.2, ...)
    ]
}
```

## Feature Specifications

### MVP Features (Version 1.0)

#### 1. Note Management
- **Create Notes**: Tap floating "+" button to create new note
- **Edit Notes**: Tap note to enter edit mode with glass text editor
- **Delete Notes**: Swipe to delete or long-press menu
- **Move Notes**: Drag and drop with physics-based movement
- **Search Notes**: Real-time search with highlight

#### 2. Liquid Glass Effects
- **Base Glass Material**: Translucent background with blur
- **Motion Response**: Subtle tilt effects using device gyroscope
- **Dynamic Lighting**: Specular highlights that follow device orientation
- **Content Adaptation**: Opacity adjusts based on text length
- **Theme Variants**: 3 free themes (Clear, Frosted, Tinted)

#### 3. Spatial Organization
- **Free-form Layout**: Notes can be positioned anywhere on canvas
- **Magnetic Clustering**: Related notes subtly attract each other
- **Z-depth Layering**: Important notes naturally come forward
- **Gesture Controls**: Pinch to zoom, rotate to reorganize

#### 4. Data Persistence
- **Local Storage**: SwiftData for offline functionality
- **iCloud Sync**: Automatic sync across user's devices
- **Conflict Resolution**: Last-write-wins with user notification

### Premium Features (Subscription)

#### 1. Advanced Glass Materials
- **Iridescent Glass**: Color-shifting materials
- **Textured Glass**: Rippled, hammered, prismatic effects
- **Dynamic Themes**: Glass that responds to time of day
- **Custom Colors**: User-defined tint colors and opacity

#### 2. Enhanced Organization
- **Categories**: Organize notes into glass folders
- **Tags**: Multi-tag support with visual indicators
- **Smart Groups**: Auto-categorization based on content
- **Archive System**: Hide completed notes without deletion

#### 3. Productivity Features
- **Reminders**: Location and time-based notifications
- **Apple Watch**: Quick note creation and viewing
- **Shortcuts Integration**: Siri support and automation
- **Export Options**: PDF, text, and image export

## UI/UX Requirements

### Design Principles
1. **Glass-First Design**: Every UI element should use glass materials
2. **Spatial Awareness**: UI should feel three-dimensional
3. **Motion Responsiveness**: Subtle reactions to device movement
4. **Content Clarity**: Never sacrifice readability for aesthetics
5. **Performance Priority**: 60fps animations at all times

### Key Interactions
- **Note Creation**: Floating glass button with ripple effect
- **Note Editing**: Smooth transition to full-screen glass editor
- **Canvas Navigation**: Smooth panning and zooming
- **Theme Selection**: Visual preview with real-time application

### Accessibility
- **VoiceOver**: Full support for screen readers
- **Dynamic Type**: Respect user's text size preferences
- **High Contrast**: Alternative themes for visibility needs
- **Reduce Motion**: Disable glass effects when requested

## Technical Implementation Details

### Glass Effect Implementation
```swift
struct LiquidGlassView: View {
    @StateObject private var motionManager = MotionManager()
    let theme: GlassTheme
    let content: () -> Content
    
    var body: some View {
        content()
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(theme.baseOpacity)
                    .blur(radius: theme.blurRadius)
                    .overlay(
                        SpecularHighlightView(
                            intensity: theme.highlightIntensity,
                            motionData: motionManager.data
                        )
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
```

### Motion Response System
```swift
class MotionManager: ObservableObject {
    @Published var data = MotionData()
    private let motionManager = CMMotionManager()
    
    struct MotionData {
        var pitch: Double = 0
        var roll: Double = 0
        var yaw: Double = 0
    }
    
    func startTracking() {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.deviceMotionUpdateInterval = 1/60
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion = motion else { return }
            
            self?.data = MotionData(
                pitch: motion.attitude.pitch,
                roll: motion.attitude.roll,
                yaw: motion.attitude.yaw
            )
        }
    }
}
```

### SwiftData + CloudKit Integration
```swift
import SwiftData
import CloudKit

// Configure the model container with CloudKit
@main
struct LiquidNotesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Note.self, NoteCategory.self], 
                       isCloudKitEnabled: true)
    }
}

// CloudKit sync happens automatically with SwiftData
class NotesViewModel: ObservableObject {
    @Published var syncStatus: SyncStatus = .idle
    
    enum SyncStatus {
        case idle, syncing, success, error(String)
    }
    
    // SwiftData handles CloudKit sync automatically
    // Manual sync trigger if needed
    func forceSyncWithCloud() {
        // SwiftData will handle the sync automatically
        // Just update UI state
        syncStatus = .syncing
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.syncStatus = .success
        }
    }
}
```

## Performance Requirements

### Target Metrics
- **App Launch**: < 2 seconds cold start
- **Note Creation**: < 100ms response time
- **Glass Animations**: Consistent 60fps
- **Memory Usage**: < 40MB for 100 notes (SwiftData efficiency)
- **Battery Impact**: Minimal with optimized Core Motion usage

### Optimization Strategies
- **Lazy Loading**: Only render visible notes
- **Animation Batching**: Group glass effects for efficiency
- **Image Compression**: Optimized asset delivery
- **Background Processing**: Smart sync scheduling

## Security & Privacy

### Data Protection
- **Encryption**: All user data encrypted at rest and in transit
- **Keychain**: Secure storage for user preferences
- **Privacy Labels**: Full transparency in App Store listing
- **No Analytics**: Respect user privacy completely

### SwiftData + CloudKit Security
- **User Authentication**: iCloud account required for sync
- **Data Isolation**: Each user's data completely isolated
- **Automatic Encryption**: SwiftData handles encryption automatically
- **Backup Strategy**: Local SwiftData as source of truth

## Development Phases

### Phase 1: Core Foundation (Weeks 1-2)
- [ ] Project setup and SwiftData models
- [ ] Basic note CRUD operations
- [ ] Simple UI with standard materials
- [ ] Local persistence working

### Phase 2: Glass Implementation (Weeks 3-4)
- [ ] Liquid Glass view components
- [ ] Motion tracking integration
- [ ] Basic glass themes
- [ ] Smooth animations

### Phase 3: Spatial Features (Weeks 5-6)
- [ ] Free-form note positioning
- [ ] Drag and drop functionality
- [ ] Zoom and pan canvas
- [ ] Gesture recognition

### Phase 4: CloudKit & Polish (Weeks 7-8)
- [ ] SwiftData CloudKit configuration
- [ ] iCloud sync testing and validation
- [ ] Performance optimization
- [ ] Accessibility compliance

### Phase 5: Premium Features (Weeks 9-10)
- [ ] Advanced glass materials
- [ ] Subscription system
- [ ] Categories and tags
- [ ] Apple Watch app

## Dependencies

### Required Frameworks
```swift
import SwiftUI
import SwiftData
import CloudKit
import CoreMotion
import WidgetKit
import Intents
import WatchConnectivity // For Apple Watch
```

### Third-Party Libraries
None required - using only Apple's native frameworks for optimal performance and size.

## Testing Strategy

### Unit Tests
- Data model validation
- CloudKit sync logic
- Glass effect calculations
- Performance benchmarks

### UI Tests
- Note creation and editing flows
- Glass animation smoothness
- Accessibility navigation
- Multi-device sync scenarios

## Success Metrics

### Technical KPIs
- **Crash Rate**: < 0.1%
- **Performance**: 60fps animations
- **Sync Success**: > 99.5%
- **User Retention**: > 40% Day 7

### Business KPIs
- **Conversion Rate**: 5-15% free to premium
- **App Store Rating**: > 4.5 stars
- **Feature Rate**: Top 10 in Productivity

## Future Roadmap

### Version 1.1
- Advanced glass materials
- Team collaboration features
- Enhanced Apple Watch app
- Shortcuts automation

### Version 1.2
- Widget complications
- iPad-specific optimizations
- Voice note integration
- Advanced search

### Version 2.0
- Vision Pro support
- AI-powered organization
- Cross-platform collaboration
- Advanced customization

---

## Implementation Notes

This PRD provides the technical foundation for building Liquid Notes. The focus is on creating a premium, performant app that showcases Apple's Liquid Glass design language while solving real user problems with sticky note applications.

Key success factors:
1. **Performance First**: Glass effects must never compromise usability
2. **Incremental Development**: Build and test core features before adding complexity
3. **User Feedback**: Gather early feedback on glass effect intensity and usability
4. **Platform Integration**: Leverage Apple's ecosystem for maximum value

The architecture supports both rapid MVP development and long-term feature expansion while maintaining code quality and performance standards.