//
//  File.swift
//  Splash30
//
//  Created by Alpay Calalli on 19.02.25.
//

import SwiftUI

struct HighlightingEffectAttribute: TextAttribute {}

struct HighlightingEffectRenderer: TextRenderer {
    
    var animationProgress: CGFloat
    var animatableData: Double {
        get { animationProgress }
        set { animationProgress = newValue }
    }
    
    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            for run in line {
                if run[HighlightingEffectAttribute.self] != nil {
                    for (index, glp) in run.enumerated() {
                        let relativePosition = CGFloat(index) / CGFloat(run.count)
                        let adjustedOpacity = max(0.3, 1 - abs(relativePosition - animationProgress))
//                        let adjustedY = max(1, 10 - (abs(relativePosition - animationProgress) * 10)
                        
                        var copy = context
                        copy.opacity = Double(adjustedOpacity)
//                        copy.translateBy(x: 0, y: adjustedY)
                        copy.draw(glp)
                    }
                } else {
                    let copy = context
                    copy.draw(run)
                }
            }
        }
    }
}

struct OnboardingTextTransition: Transition {
    static var properties: TransitionProperties {
        TransitionProperties(hasMotion: true)
    }
    
    func body(content: Content, phase: TransitionPhase) -> some View {
        let progress: CGFloat = phase.isIdentity ? 3 : -1
        let renderer = HighlightingEffectRenderer(animationProgress: progress)
        
        content.transaction { transaction in
            if !transaction.disablesAnimations {
                transaction.animation = .easeInOut(duration: 2)
            }
        } body: { view in
            view.textRenderer(renderer)
        }
    }
}

extension Text.Layout {
    var flattenedRuns: some RandomAccessCollection<Text.Layout.Run> {
        self.flatMap { line in
            line
        }
    }
    
    var flattenedRunSlices: some RandomAccessCollection<Text.Layout.RunSlice> {
        flattenedRuns.flatMap(\.self)
    }
}

struct ColorfulRender: TextRenderer {
    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        // Iterate through RunSlice and their indices
        for (index, slice) in layout.flattenedRunSlices.enumerated() {
            // Calculate the angle of color adjustment based on the index
            let degree = Angle.degrees(360 / Double(index + 1))
            // Create a copy of GraphicsContext
            var copy = context
            // Apply hue rotation filter
            copy.addFilter(.hueRotation(degree))
            // Draw the current Slice in the context
            copy.draw(slice)
        }
    }
}
