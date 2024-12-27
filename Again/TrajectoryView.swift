//
//  TrajectoryView.swift
//  PlaygroundExploration
//
//  Created by Alpay Calalli on 16.12.24.
//

import UIKit
import Vision
import SwiftUI
import SpriteKit

class TrajectoryView: SKView, AnimatedTransitioning {
    
    // MARK: - Public Properties
    var glowingBallScene: BallScene?
    var outOfROIPoints = 0
    var points: [VNPoint] = [] {
        didSet {
            updatePathLayer()
        }
    }
    
    // MARK: - Private Properties
    private let pathLayer = CAShapeLayer()
    private let shadowLayer = CAShapeLayer()
    private let gradientMask = CAShapeLayer()
    private let gradientLayer = CAGradientLayer()
    
    // MARK: - Life Cycle
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        allowsTransparency = true
        backgroundColor = UIColor.clear
        setupLayer()
        glowingBallScene = BallScene(size: CGSize(width: frame.size.width, height: frame.size.height))
        presentScene(glowingBallScene!)
    }

    // MARK: - Public Methods
    
    func resetPath() {
        let trajectory = UIBezierPath()
        pathLayer.path = trajectory.cgPath
        shadowLayer.path = trajectory.cgPath
        glowingBallScene?.removeAllChildren()
    }

    // MARK: - Private Methods
    
    private func setupLayer() {
        shadowLayer.strokeColor = UIColor(displayP3Red: 0 / 255, green: 0 / 255, blue: 254 / 255, alpha: 0.15).cgColor
        shadowLayer.lineWidth = 5.0
        shadowLayer.fillColor = UIColor.clear.cgColor
        layer.addSublayer(shadowLayer)
        pathLayer.lineWidth = 2.5
        pathLayer.fillColor = UIColor.clear.cgColor
        pathLayer.strokeColor = UIColor(displayP3Red: 0 / 255, green: 254 / 255, blue: 254 / 255, alpha: 0.35).cgColor
        layer.addSublayer(pathLayer)
        gradientLayer.frame = bounds
        gradientLayer.colors = [UIColor(displayP3Red: 254 / 255, green: 234 / 255, blue: 0, alpha: 1).cgColor,
                                UIColor(displayP3Red: 252 / 255, green: 119 / 255, blue: 0, alpha: 1).cgColor]
        layer.addSublayer(gradientLayer)
    }
    
    private func updatePathLayer() {
        let trajectory = UIBezierPath()
        guard let startingPoint = points.first else {
            return
        }
        trajectory.move(to: startingPoint.location)
        for point in points.dropFirst() {
            trajectory.addLine(to: point.location)
        }
        
        // Scale the trajectory.
        let flipVertical = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -1)
        trajectory.apply(flipVertical)
        trajectory.apply(CGAffineTransform(scaleX: bounds.width, y: bounds.height))
        trajectory.lineWidth = 12
        
        // Assign the trajectory to the user interface layers.
        shadowLayer.path = trajectory.cgPath
        pathLayer.path = trajectory.cgPath
        gradientMask.path = trajectory.cgPath
        gradientLayer.mask = gradientMask
        
        // Scale up a normalized scene.
        if glowingBallScene!.size.width <= 1.0 || glowingBallScene!.size.height <= 1.0 {
            glowingBallScene = BallScene(size: CGSize(width: frame.size.width, height: frame.size.height))
            presentScene(glowingBallScene!)
        }
        
        // Scale up the trajectory points.
        var scaledPoints: [CGPoint] = []
        for point in points {
            scaledPoints.append(point.location.applying(CGAffineTransform(scaleX: frame.size.width, y: frame.size.height)))
        }
        
        // Animate the ball across the scene.
        if scaledPoints.last != nil {
            glowingBallScene!.flyBall(points: scaledPoints)
        }
    }
    
}



enum AnimatedTransitionType {
    case fadeIn
    case fadeOut
    case popUp
    case popOut
}

protocol AnimatedTransitioning {
    func performTransition(_ transition: AnimatedTransitionType,
                           duration: TimeInterval)
    func performTransition(_ transition: AnimatedTransitionType,
                           duration: TimeInterval,
                           completion: (() -> Void)?)
    func performTransitions(_ transitions: [AnimatedTransitionType],
                            durations: [TimeInterval],
                            delayBetween: TimeInterval,
                            completion: (() -> Void)?)
}

extension AnimatedTransitioning where Self: UIView {
    
    func performTransition(_ transition: AnimatedTransitionType,
                           duration: TimeInterval) {
        performTransition(transition, duration: duration, completion: nil)
    }
    
    func performTransition(_ transition: AnimatedTransitionType,
                           duration: TimeInterval,
                           completion: (() -> Void)?) {
        switch transition {
        case .fadeIn:
            UIView.transition(with: self,
                              duration: duration,
                              options: .transitionCrossDissolve,
                              animations: {
                self.isHidden = false
            }) { _ in
                completion?()
            }
        case .fadeOut:
            UIView.transition(with: self,
                              duration: duration,
                              options: .transitionCrossDissolve,
                              animations: {
                self.isHidden = true
            }) { _ in
                completion?()
            }
        case .popUp:
            alpha = 0
            transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            UIView.animate(withDuration: duration,
                           delay: 0,
                           usingSpringWithDamping: 0.5,
                           initialSpringVelocity: 5,
                           options: [.curveEaseIn],
                           animations: {
                self.transform = CGAffineTransform.identity
                self.alpha = 1
            }) { _ in
                completion?()
            }
        case .popOut:
            alpha = 1
            transform = CGAffineTransform.identity
            UIView.animate(withDuration: duration,
                           delay: 0,
                           options: [.curveEaseOut],
                           animations: {
                self.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
                self.alpha = 0
            }) { _ in
                completion?()
            }
        }
    }
    
    func performTransitions(_ transitions: [AnimatedTransitionType],
                            durations: [TimeInterval],
                            delayBetween: TimeInterval,
                            completion: (() -> Void)?) {

        guard let transition = transitions.first else {
            completion?()
            return
        }
        
        let duration = durations.first ?? 0.25
        let view = self
        view.performTransition(transition, duration: duration) {
            let remainingTransitions = Array(transitions.dropFirst())
            let remainingDurations = Array(durations.dropFirst())
            if remainingTransitions.isEmpty {
                Timer.scheduledTimer(withTimeInterval: delayBetween, repeats: false) { _ in
                    view.performTransitions(remainingTransitions, durations: remainingDurations, delayBetween: delayBetween, completion: completion)
                }
            } else {
                completion?()
            }
        }
    }
    
}

class BallScene: SKScene {
    
    // MARK: - Life Cycle
    
    required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
        }
        
    override init(size: CGSize) {
        super.init(size: size)
        self.backgroundColor = UIColor.clear
    }
    
    // MARK: - Public Methods
    
    func flyBall(points: [CGPoint]) {
        DispatchQueue.main.async {
            if self.children.isEmpty {
                if let fireParticle = SKEmitterNode(fileNamed: "FireBall2") {
                    fireParticle.position = points.first!
                    fireParticle.targetNode = self
                    self.addChild(fireParticle)
                }
            } else {
                self.children.last?.position = points.last!
            }
        }
    }
    
}
