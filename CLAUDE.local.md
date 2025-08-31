# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project: LiquidNotes

A SwiftUI iOS app implementing Apple's Liquid Glass design language for modern productivity and notes with spatial organization.

## Development Commands

### Build & Run
```bash
# Build the project
xcodebuild -scheme LiquidNotes -configuration Debug build

# Run on simulator
xcodebuild -scheme LiquidNotes -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build-for-testing

# Clean build folder
xcodebuild -scheme LiquidNotes clean

### Testing
```bash
# Run unit tests
xcodebuild test -scheme LiquidNotes -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Run specific test
xcodebuild test -scheme LiquidNotes -only-testing:LiquidNotesTests/TestClassName/testMethodName
```

## Architecture Overview

### MVVM with SwiftData
- **Models**: SwiftData entities (`Note`, `NoteCategory`, `Folder`) in `/Models`
- **ViewModels**: Business logic in `/ViewModels` (e.g., `NotesViewModel`)
- **Views**: SwiftUI views organized by feature in `/Views`
- **Entry Point**: `LiquidNotesApp.swift` configures SwiftData container

### Key Components

#### Glass Effects System
- **Location**: `/Extensions/SwiftUI+GlassEffects.swift`
- Implements translucent materials with motion response
- Uses Core Motion for device orientation tracking

#### Spatial Canvas
- **Main View**: `/Views/SpatialCanvasView.swift`
- Free-form note positioning with drag constraints
- Physics-based interactions and magnetic clustering

#### Data Persistence
- SwiftData models with CloudKit sync capability
- Automatic persistence through `.modelContainer` modifier
- Models define relationships (e.g., Note -> Category)

### Widget Extension
- **Location**: `/LiquidNotesWidget/`
- Includes live activities and control widgets
- Shares data model with main app

## Core Requirements

### iOS26 Implementation
- **Target Platform**: iOS 17.0+ (iOS26 design language)
- **UI Framework**: SwiftUI 5.0+ with glass materials
- **Deployment Target**: iOS 17.0 minimum

### Documentation and Resources

#### Fallback Protocol
When `apple-doc-mcp` lacks information:
1. Inform the user of the gap
2. Specify alternative approach
3. Proceed after explaining solution

### Code Quality Standards

#### Comments Policy
- **NO new comments** in code files
- **DELETE existing comments** when editing
- Self-documenting code through clear naming

### Git Operations

#### Commit Messages
- Keep **very short** and descriptive
- **NO mention of Claude**
- Examples:
  - "Add note drag constraints"
  - "Fix dark mode text visibility"
  - "Update glass effect opacity"

## Implementation Priorities

1. **Native iOS first** - Use Apple's built-in components
2. **Liquid glass aesthetic** - Consistent glass materials throughout
3. **Clean code** - Remove comments, maintain readability

## File Organization

```
LiquidNotes/
├── LiquidNotesApp.swift         # App entry point with SwiftData config
├── Models/                       # SwiftData entities
│   ├── Note.swift               # Main note model
│   ├── NoteCategory.swift       # Category grouping
│   └── Folder.swift             # Folder organization
├── Views/
│   ├── MainTabView.swift        # Tab navigation
│   ├── SpatialCanvasView.swift  # Main canvas for notes
│   ├── SpatialTabView.swift     # Spatial tab interface
│   ├── NoteViews/               # Note-specific views
│   └── Components/              # Reusable UI components
├── ViewModels/
│   └── NotesViewModel.swift     # Main business logic
├── Extensions/                   # Swift extensions
│   ├── SwiftUI+GlassEffects.swift
│   └── SwiftUI+iOS18Compatibility.swift
├── Services/
│   └── GiphyService.swift       # External API integration
└── Utilities/
    ├── HapticManager.swift      # Haptic feedback
    └── MotionManager.swift      # Device motion tracking
```

## Common Tasks

### Add New Glass Effect
1. Extend `SwiftUI+GlassEffects.swift`
2. Use `.ultraThinMaterial` as base
3. Apply motion response from `MotionManager`

### Create New Note Type
1. Add properties to `Note` model
2. Update `NotesViewModel` for business logic
3. Create view in `/Views/NoteViews/`

### Implement Widget Feature
1. Work in `/LiquidNotesWidget/`
2. Share data through App Groups
3. Use SwiftData for persistence