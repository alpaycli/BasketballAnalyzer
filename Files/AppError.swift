//
//  AppError.swift
//  BasketballAnalyzer
//
//  Created by Alpay Calalli on 01.01.25.
//

import UIKit
import Foundation

import SwiftUI

struct OnboardingAppearanceEffectRenderer: TextRenderer, Animatable {
    var elapsedTime: TimeInterval
    
    var elementDuration: TimeInterval
    
    var totalDuration: TimeInterval
    
    var spring: Spring {
        .snappy(duration: elementDuration - 0.05, extraBounce: 0.4)
    }
    
    var animatableData: Double {
        get { elapsedTime }
        set { elapsedTime = newValue }
    }
    
    init(elapsedTime: TimeInterval, elementDuration: Double = 1.5, totalDuration: TimeInterval) {
        self.elapsedTime = min(elapsedTime, totalDuration)
        self.elementDuration = min(elementDuration, totalDuration)
        self.totalDuration = totalDuration
    }
    
    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for run in layout.flattenedRuns {
            if run[OnboardingEmphasisAttribute.self] != nil {
                let delay = elementDelay(count: run.count)

                for (index, slice) in run.enumerated() {
                    let timeOffset = TimeInterval(index) * delay
                    let elementTime = max(0, min(elapsedTime - timeOffset, elementDuration))

                    var copy = context
                    draw(slice, at: elementTime, in: &copy)
                }
            } else {
                var copy = context
                copy.opacity = UnitCurve.easeIn.value(at: elapsedTime / 0.2)
                copy.draw(run)
            }
        }
    }
    
    /// Calculates how much time passes between the start of two consecutive
     /// element animations.
     ///
     /// For example, if there's a total duration of 1 s and an element
     /// duration of 0.5 s, the delay for two elements is 0.5 s.
     /// The first element starts at 0 s, and the second element starts at 0.5 s
     /// and finishes at 1 s.
     ///
     /// However, to animate three elements in the same duration,
     /// the delay is 0.25 s, with the elements starting at 0.0 s, 0.25 s,
     /// and 0.5 s, respectively.
     func elementDelay(count: Int) -> TimeInterval {
       let count = TimeInterval(count)
       let remainingTime = totalDuration - count * elementDuration

       return max(remainingTime / (count + 1), (totalDuration - elementDuration) / count)
     }
    
    func draw(_ slice: Text.Layout.RunSlice, at time: TimeInterval, in context: inout GraphicsContext) {
      let progress = time / elementDuration

      let opacity = UnitCurve.easeIn.value(at: 1.4 * progress)

      let blurRadius =
      slice.typographicBounds.rect.height / 16 *
      UnitCurve.easeIn.value(at: 1 - progress)

      // The y-translation derives from a spring, which requires a
      // time in seconds.
      let translationY = spring.value(
        fromValue: -slice.typographicBounds.descent,
        toValue: 0,
        initialVelocity: 0,
        time: time)

      context.translateBy(x: 0, y: translationY)
      context.addFilter(.blur(radius: blurRadius))
      context.opacity = opacity
      context.draw(slice, options: .disablesSubpixelQuantization)
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

struct OnboardingEmphasisAttribute: TextAttribute {
    
}

enum AppError: Error {
    case captureSessionSetup(reason: String)
    case createRequestError(reason: String)
    case videoReadingError(reason: String)
    
    static func display(_ error: Error, inViewController viewController: UIViewController) {
        if let appError = error as? AppError {
            appError.displayInViewController(viewController)
        } else {
            print(error)
        }
    }
    
    func displayInViewController(_ viewController: UIViewController) {
        let title: String?
        let message: String?
        switch self {
        case .captureSessionSetup(let reason):
            title = "AVSession Setup Error"
            message = reason
        case .createRequestError(let reason):
            title = "Error Creating Vision Request"
            message = reason
        case .videoReadingError(let reason):
            title = "Error Reading Recorded Video."
            message = reason
        }
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        viewController.present(alert, animated: true)
    }
}
