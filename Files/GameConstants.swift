//
//  GameConstants.swift
//  PlaygroundExploration
//
//  Created by Alpay Calalli on 16.12.24.
//

import Vision
import Foundation

struct GameConstants {
    static let hoopLength = 0.61
    static let trajectoryLength = 15
    static let maxPoseObservations = 45
    static let noObservationFrameLimit = 20
    static let maxDistanceWithCurrentTrajectory: CGFloat = 165
    static let maxTrajectoryInFlightPoseObservations = 10
    
    static let bodyPoseDetectionMinConfidence: VNConfidence = 0.6
    static let trajectoryDetectionMinConfidence: VNConfidence = 0.9
    static let bodyPoseRecognizedPointMinConfidence: VNConfidence = 0.1
}
