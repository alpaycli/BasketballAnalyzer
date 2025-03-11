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

class TrajectoryView: UIView, AnimatedTransitioning {
    var roi = CGRect.null
    var inFlight = false
    var fullTrajectory = UIBezierPath()
    var duration = 0.0
    var speed = 0.0
    var uniquePoints: [CGPoint] = []
    var points: [VNPoint] = [] {
        didSet {
            updatePathLayer()
        }
    }
    
    private let pathLayer = CAShapeLayer()
    private let blurLayer = CAShapeLayer()
    private let shadowLayer = CAShapeLayer()

    private var distanceWithCurrentTrajectory: CGFloat = 0
    
    private var isTrajectoryInTopOfScreen: Bool {
        if let middlePoint = points[safe: points.count / 2] {
            return middlePoint.location.y > 0.5
        }
        
        return false
    }
    
    var finalBallLocation: CGPoint {
        // Normalized final bag location
        let bagLocation = fullTrajectory.currentPoint
        let flipVertical = CGAffineTransform.verticalFlip
        let scaleDown = CGAffineTransform(scaleX: (1 / bounds.width), y: (1 / bounds.height))
        let normalizedLocation = bagLocation.applying(scaleDown).applying(flipVertical)
        return normalizedLocation
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }

    func resetPath() {
        uniquePoints = []
        
        print("reset path called ")
        inFlight = false
        distanceWithCurrentTrajectory = 0
        fullTrajectory.removeAllPoints()
        pathLayer.path = fullTrajectory.cgPath
        blurLayer.path = fullTrajectory.cgPath
        shadowLayer.path = fullTrajectory.cgPath
    }

    func addPath(_ path: CGPath, color: UIColor) {
        fullTrajectory.cgPath = path
        pathLayer.lineWidth = 2
        pathLayer.strokeColor = color.cgColor
        pathLayer.path = fullTrajectory.cgPath
        shadowLayer.lineWidth = 4
        shadowLayer.path = fullTrajectory.cgPath
    }

    private func setupLayer() {
        shadowLayer.lineWidth = 3.0
        shadowLayer.lineCap = .round
        shadowLayer.fillColor = UIColor.clear.cgColor
        shadowLayer.strokeColor = #colorLiteral(red: 0.9882352941, green: 0.4666666667, blue: 0, alpha: 0.4519210188).cgColor
        layer.addSublayer(shadowLayer)
        blurLayer.lineWidth = 3.0
        blurLayer.lineCap = .round
        blurLayer.fillColor = UIColor.clear.cgColor
        blurLayer.strokeColor = #colorLiteral(red: 0.9960784314, green: 0.737254902, blue: 0, alpha: 0.597468964).cgColor
        layer.addSublayer(blurLayer)
        pathLayer.lineWidth = 4.0
        pathLayer.lineCap = .round
        pathLayer.fillColor = UIColor.clear.cgColor
        pathLayer.strokeColor = #colorLiteral(red: 0.9960784314, green: 0.737254902, blue: 0, alpha: 0.7512574914).cgColor
        layer.addSublayer(pathLayer)
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
        let flipVertical = CGAffineTransform.verticalFlip
        trajectory.apply(flipVertical)
        trajectory.apply(CGAffineTransform(scaleX: bounds.width, y: bounds.height))
        let startScaled = startingPoint.location.applying(flipVertical).applying(CGAffineTransform(scaleX: bounds.width, y: bounds.height))
        var distanceWithCurrentTrajectory: CGFloat = 0
        if inFlight {
            distanceWithCurrentTrajectory = startScaled.distance(to: fullTrajectory.currentPoint)
        }
        
        if (roi.contains(trajectory.currentPoint) || (inFlight && roi.contains(startScaled))) {
            if !inFlight {
                // This is the first trajectory detected for the shot. Compute the speed in pts/sec
                // Length of the trajectory is calculated by measuring the distance between the first and last point on the trajectory
                // length = sqrt((final.x - start.x)^2 + (final.y - start.y)^2)
                let trajectoryLength = trajectory.currentPoint.distance(to: startScaled)
                
                // Speed is computed by dividing the length of the trajectory with the duration for the trajectory
                speed = Double(trajectoryLength) / duration
                fullTrajectory = trajectory
            }
            let trajectoryLength = trajectory.currentPoint.distance(to: startScaled)
            if trajectoryLength > 100 {
                fullTrajectory.append(trajectory)
            }
            shadowLayer.path = fullTrajectory.cgPath
            blurLayer.path = fullTrajectory.cgPath
            pathLayer.path = fullTrajectory.cgPath
            inFlight = true
        }
    }
}

