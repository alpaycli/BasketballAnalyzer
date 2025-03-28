//
//  ContentViweModel.swift
//  Splash30
//
//  Created by Alpay Calalli on 08.03.25.
//

import SwiftUI

/// Used for communication between ``HomeView`` and ``ContentAnalysisViewController``.
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
   
   var showSetupStateLabels: Bool {
       guard manualHoopSelectorState != .inProgress else { return false }
       
       return !setupStateModel.isAllDone
   }
   
   var showMetricsAndScore: Bool {
       !isVideoEnded && !isFinishButtonPressed
   }
   
   var isHoopPlaced: Bool {
      setupStateModel.hoopDetected
   }
   
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
}
