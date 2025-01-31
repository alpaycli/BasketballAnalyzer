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

enum ShotResult: Equatable {
    case score
    case miss(ShotMissReason)
    
    enum ShotMissReason: String {
        case short = "Short"
        case long = "Long"
        // means hit the rim
        case none = "Miss" // or nice try
    }
    
    var description: String {
        switch self {
        case .score:
            "✅Score"
        case .miss(let shotMissReason):
            "❌" + shotMissReason.rawValue
        }
    }
}

struct ShotMetrics: Equatable {
    let shotResult: ShotResult
    var speed: Double
    let releaseAngle: Double
    let jumpshotType: JumpshotType
    
    init(
        shotResult: ShotResult = .miss(.none),
        speed: Double = 0.0,
        releaseAngle: Double = 0.0,
        jumpshotType: JumpshotType = .none
    ) {
        self.shotResult = shotResult
        self.speed = speed
        self.releaseAngle = releaseAngle
        self.jumpshotType = jumpshotType
    }
}


struct PlayerStats: Equatable {
    private(set) var totalScore = 0
    private(set) var shotCount = 0
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
    private(set) var shotPaths: [CGPath] = []
    private(set) var allSpeeds: [Double] = []
    private(set) var allReleaseAngles: [Double] = []
    private(set) var shotResults: [ShotResult] = []
    
//    var allReleaseSpeeds: [Double] = [] // or durations
//    var topReleaseSpeed = 0.0 // or duration
//    var avgReleaseSpeed = 0.0 // or duration
    
    mutating func adjustMetrics(isShotWentIn: Bool) {
        shotCount += 1
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
    
    mutating func storeShotResult(_ shotResult: ShotResult) {
        shotResults.append(shotResult)
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
