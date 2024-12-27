//
//  GameConstants.swift
//  PlaygroundExploration
//
//  Created by Alpay Calalli on 16.12.24.
//

import Foundation

struct GameConstants {
    static let maxThrows = 8
    static let newGameTimer = 5
    static let boardLength = 1.22
    static let trajectoryLength = 15
    static let maxPoseObservations = 45
    static let noObservationFrameLimit = 20
    static let maxDistanceWithCurrentTrajectory: CGFloat = 250
    static let maxTrajectoryInFlightPoseObservations = 10
}
