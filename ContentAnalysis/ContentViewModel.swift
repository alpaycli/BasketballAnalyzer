//
//  ContentViweModel.swift
//  Splash30
//
//  Created by Alpay Calalli on 08.03.25.
//

import SwiftUI

@Observable
class ContentViewModel {
    /// The center point of the detected hoop in view coordinates.
    ///
    /// - Used in `HomeView` to position `EditHoopTip` above the hoop.
    /// - Set in `ContentAnalysisViewController` after converting from Vision's coordinate system.
    /// - The point is already transformed into view coordinates.
    var hoopCenterPoint: CGPoint?
    
    var manualHoopSelectorState: AreaSelectorState = .none
    var lastShotMetrics: ShotMetrics? = nil
    var playerStats = PlayerStats()
    var setupGuideLabel: String? = nil
    var setupStateModel = SetupStateModel()
    var isFinishButtonPressed = false
    var isRecordingPermissionDenied = false
    var isVideoEnded = false
    
    func reset() {
        manualHoopSelectorState = .none
        lastShotMetrics = nil
        playerStats.reset()
        setupGuideLabel = nil
        setupStateModel = .init()
        isFinishButtonPressed = false
        isRecordingPermissionDenied = false
        isVideoEnded = false
    }
    
    var isHoopPlaced: Bool {
        setupStateModel.hoopDetected
    }
}
