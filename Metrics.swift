//
//  JumpshotType.swift
//  BasketballAnalyzer
//
//  Created by Alpay Calalli on 08.01.25.
//

import Vision
import Foundation

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
    
    init(
        shotResult: ShotResult = .miss(.none),
        speed: Double = 0.0,
        releaseAngle: Double = 0.0
    ) {
        self.shotResult = shotResult
        self.speed = speed
        self.releaseAngle = releaseAngle
    }
}


struct PlayerStats: Equatable {
    private(set) var totalScore = 0
    private(set) var shotCount = 0
    var topSpeed: Double {
        allSpeeds.max() ?? 0
    }
    var avgReleaseAngle: Double? {
        guard !allSpeeds.isEmpty else { return nil }
        let sum = Int(allReleaseAngles.reduce(0, +))
        return Double(sum / allReleaseAngles.count)
    }
    var avgSpeed: Double? {
        let allSpeeds = allSpeeds.filter({ $0.isNormal })
        guard !allSpeeds.isEmpty else { return nil }
        let sum = Int(allSpeeds.reduce(0, +))
        return Double(sum / allSpeeds.count)
    }
    var mostMissReason: String? {
        shotResults
            .filter {
                if case .miss(.long) = $0 {
                    return true
                } else if case .miss(.short) = $0 {
                    return true
                }
                return false
            }
            .map { $0.description }
            .mostFrequentElement()
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

extension Array where Element == String {
    func mostFrequentElement() -> String? {
        guard let first = first else { return nil }
        
        var dict: [String : Int] = [first : 0]
        
        for item in self {
            if let existingItem = dict.first(where: { $0.key == item }) {
                dict.updateValue(existingItem.value + 1, forKey: existingItem.key)
            } else {
                // create new one with initial value 0
                dict[item] = 0
            }
        }
        
        return dict.max(by: { $0.value < $1.value })?.key
    }
    
//    func mostFrequentElement() -> String? {
//        let counts = self.reduce(into: [:]) { counts, element in
//            counts[element, default: 0] += 1
//        }
//        return counts.max(by: { $0.value < $1.value })?.key
//    }
}
