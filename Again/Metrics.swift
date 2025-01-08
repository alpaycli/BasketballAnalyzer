//
//  JumpshotType.swift
//  BasketballAnalyzer
//
//  Created by Alpay Calalli on 08.01.25.
//

import Vision
import Foundation

enum JumpshotType: String, CaseIterable {
    case underhand = "Underhand"
    case normal = "Normal"
    case none = "None"
}

struct ShotMetrics: Equatable {
    let isScore: Bool
    var speed: Double
    let releaseAngle: Double
    let jumpshotType: JumpshotType
    
    init(
        isScore: Bool = false,
        speed: Double = 0.0,
        releaseAngle: Double = 0.0,
        jumpshotType: JumpshotType = .none
    ) {
        self.isScore = isScore
        self.speed = speed
        self.releaseAngle = releaseAngle
        self.jumpshotType = jumpshotType
    }
}


struct PlayerStats {
    var totalScore = 0
    var throwCount = 0
    var topSpeed: Double {
        allSpeeds.max() ?? 0
    }
    var avgReleaseAngle: Double {
        let sum = Int(allReleaseAngles.reduce(0, +))
        return Double(sum / allReleaseAngles.count)
    }
    var avgSpeed: Double {
        let sum = Int(allSpeeds.reduce(0, +))
        return Double(sum / allSpeeds.count)
    }
    
//    var poseObservations = [VNHumanBodyPoseObservation]()
    var shotPaths: [CGPath] = []
    var allSpeeds: [Double] = []
    var allReleaseAngles: [Double] = []
    
//    var allReleaseSpeeds: [Double] = [] // or durations
//    var topReleaseSpeed = 0.0 // or duration
//    var avgReleaseSpeed = 0.0 // or duration
    
    mutating func adjustMetrics(isShotWentIn: Bool) {
        throwCount += 1
        if isShotWentIn {
            totalScore += 1
        }
    }
    
    mutating func storeShotPath(_ path: CGPath) {
        shotPaths.append(path)
    }
    
    mutating func storeShotSpeed(_ speed: Double) {
        allSpeeds.append(speed)
    }
    
    mutating func storeReleaseAngle(_ angle: Double) {
        allReleaseAngles.append(angle)
    }
    
    func getReleaseAngle(poseObservations: [VNHumanBodyPoseObservation]) -> Double {
        var releaseAngle: Double = 0.0
        if !poseObservations.isEmpty {
            let observationCount = poseObservations.count
            let postReleaseObservationCount = GameConstants.trajectoryLength + GameConstants.maxTrajectoryInFlightPoseObservations
            let keyFrameForReleaseAngle = observationCount > postReleaseObservationCount ? observationCount - postReleaseObservationCount : 0
            let observation = poseObservations[keyFrameForReleaseAngle]
            let (rightElbow, rightWrist) = armJoints(for: observation)
            // Release angle is computed by measuring the angle forearm (elbow to wrist) makes with the horizontal
            releaseAngle = rightElbow.angleFromHorizontal(to: rightWrist)
        }
        return releaseAngle
    }

    mutating func getLastJumpshotType(poseObservations: [VNHumanBodyPoseObservation]) -> JumpshotType {
//        guard let actionClassifier = try? PlayerActionClassifier(configuration: MLModelConfiguration()),
//              let poseMultiArray = prepareInputWithObservations(poseObservations),
//              let predictions = try? actionClassifier.prediction(poses: poseMultiArray),
//              let throwType = ThrowType(rawValue: predictions.label.capitalized) else {
//            return .none
//        }
//        return throwType
        return .underhand
    }
}

func armJoints(for observation: VNHumanBodyPoseObservation) -> (CGPoint, CGPoint) {
    var rightElbow = CGPoint(x: 0, y: 0)
    var rightWrist = CGPoint(x: 0, y: 0)

    guard let identifiedPoints = try? observation.recognizedPoints(.all) else {
        return (rightElbow, rightWrist)
    }
    for (key, point) in identifiedPoints where point.confidence > 0.1 {
        switch key {
        case .rightElbow:
            rightElbow = point.location
        case .rightWrist:
            rightWrist = point.location
        default:
            break
        }
    }
    return (rightElbow, rightWrist)
}
