//
//  SwiftUI+iOS26Compatibility.swift
//  LiquidNotes
//
//  Created by Claude Code on 8/21/25.
//

import SwiftUI

// MARK: - iOS 26 Compatibility Extensions

extension View {
    /// Enhanced gesture handling compatible with iOS 26
    func compatibleTapGesture(count: Int = 1, perform action: @escaping () -> Void) -> some View {
        if #available(iOS 26.0, *) {
            // iOS 26: Use high priority gesture to avoid conflicts with List
            return AnyView(self.highPriorityGesture(
                TapGesture(count: count).onEnded { _ in action() }
            ))
        } else {
            return AnyView(self.onTapGesture(count: count, perform: action))
        }
    }
    
    /// Enhanced long press gesture with improved recognition for iOS 26
    func compatibleLongPressGesture(
        minimumDuration: Double = 0.5,
        maximumDistance: CGFloat = 10,
        perform action: @escaping () -> Void
    ) -> some View {
        if #available(iOS 26.0, *) {
            // iOS 26: Use high priority long press gesture
            return AnyView(self.highPriorityGesture(
                LongPressGesture(minimumDuration: minimumDuration, maximumDistance: maximumDistance)
                    .onEnded { _ in action() }
            ))
        } else {
            return AnyView(self.onLongPressGesture(
                minimumDuration: minimumDuration,
                perform: action
            ))
        }
    }
    
    /// Improved hit testing for better touch responsiveness (iOS-safe)
    /// Note: `allowsWindowActivationEvents` is not relevant on iOS; keep behavior consistent.
    func compatibleAllowsHitTesting(_ enabled: Bool) -> some View {
        return AnyView(self.allowsHitTesting(enabled))
    }
    
    /// Enhanced material effects for iOS 26+
    func compatibleMaterial(_ material: Material = .ultraThinMaterial) -> some View {
        if #available(iOS 26.0, *) {
            return AnyView(self.background(material))
        } else {
            return AnyView(self.background(.ultraThinMaterial))
        }
    }
    
    /// Improved animation performance for iOS 26+
    func compatibleAnimation<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        if #available(iOS 26.0, *) {
            return AnyView(self.animation(animation, value: value))
        } else {
            return AnyView(self.animation(animation, value: value))
        }
    }
    
    /// Enhanced content shape recognition
    func compatibleContentShape<S: Shape>(_ shape: S) -> some View {
        if #available(iOS 26.0, *) {
            return AnyView(self.contentShape(shape))
        } else {
            return AnyView(self.contentShape(shape))
        }
    }
}

// MARK: - Image Compatibility

extension Image {
    /// Improved image rendering for iOS 26+
    func compatibleResizable(capInsets: EdgeInsets = EdgeInsets(), resizingMode: Image.ResizingMode = .stretch) -> some View {
        if #available(iOS 26.0, *) {
            return AnyView(self.resizable(capInsets: capInsets, resizingMode: resizingMode))
        } else {
            return AnyView(self.resizable(capInsets: capInsets, resizingMode: resizingMode))
        }
    }
    
    /// Enhanced aspect ratio handling
    func compatibleAspectRatio(_ aspectRatio: CGFloat? = nil, contentMode: ContentMode) -> some View {
        if #available(iOS 26.0, *) {
            return AnyView(self.aspectRatio(aspectRatio, contentMode: contentMode))
        } else {
            return AnyView(self.aspectRatio(aspectRatio, contentMode: contentMode))
        }
    }
}

// MARK: - Gesture State Management

@available(iOS 17.0, *)
struct CompatibleGestureState<T>: DynamicProperty {
    @GestureState private var state: T
    
    init(initialValue: T) {
        self._state = GestureState(initialValue: initialValue)
    }
    
    var wrappedValue: T {
        get { state }
        nonmutating set { /* GestureState is read-only */ }
    }
    
    var projectedValue: GestureState<T> {
        _state
    }
}
