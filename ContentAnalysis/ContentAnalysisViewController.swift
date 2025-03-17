//
//  ContentAnalysisViewController.swift
//  Splash30
//
//  Created by Alpay Calalli on 08.03.25.
//

import Vision
import ReplayKit
import AVFoundation
import SwiftUI

class ContentAnalysisViewController: UIViewController {
   
   private let gameManager = GameManager.shared
   private let viewModel: ContentViewModel
   private let isTestMode: Bool
   
   private var recordedVideoSource: AVAsset?
   
   // MARK: - Views
   
   private var cameraViewController = CameraViewController()
   private var trajectoryView = TrajectoryView()
   private let hoopBoundingBox = BoundingBoxView()
   private let playerBoundingBox = BoundingBoxView()
   private let jointSegmentView = JointSegmentView()
   
   private var manualHoopAreaSelectorView: AreaSelectorView!
   private var hoopRegion: CGRect = .zero {
      didSet {
         hoopSafeAreaView = UIView(frame: hoopRegion.inset(by: .init(top: -100, left: -100, bottom: -50, right: -100)))
      }
   }
   
   /// A view that represents an expanded safety area around the detected basketball hoop.
   ///
   /// It is used to filter out useless trajectories.
   private var hoopSafeAreaView = UIView(frame: .zero)
   
   // MARK: - Requests
   
   private let detectPlayerRequest = VNDetectHumanBodyPoseRequest()
   private lazy var detectTrajectoryRequest: VNDetectTrajectoriesRequest! = VNDetectTrajectoriesRequest(frameAnalysisSpacing: .zero, trajectoryLength: GameConstants.trajectoryLength)
   // MARK: - Others
   
   private var playerDetected: Bool {
      viewModel.setupStateModel.playerDetected
   }
   
   private let trajectoryQueue = DispatchQueue(label: "trajectoryRequestQueue", qos: .userInteractive)
   
   private var trajectoryInFlightPoseObservations = 0
   
   /// Counts of frame when there is no detected trajectory observation.
   private var noObservationFrameCount = 0
   
   // MARK: - Init
   
   init(
      recordedVideoSource: AVAsset?,
      isTestMode: Bool,
      viewModel: ContentViewModel
   ) {
      self.recordedVideoSource = recordedVideoSource
      self.isTestMode = isTestMode
      self.viewModel = viewModel
      super.init(nibName: nil, bundle: nil)
   }
   
   required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
   }
   
   // MARK: - Life Cycle
   
   override func viewDidLoad() {
      super.viewDidLoad()
      startObservingStateChanges()
      setupHoopBoundingBox()
      setUIElements()
      configureCameraView()
   }
   
   override func viewDidAppear(_ animated: Bool) {
      trajectoryView.roi = cameraViewController.viewRectForVisionRect(.init(x: 0, y: 0.5, width: 1, height: 0.5))
   }
   
   override func viewDidDisappear(_ animated: Bool) {
      super.viewDidDisappear(animated)
      
      gameManager.stateMachine.enter(GameManager.InactiveState.self)
      
      // This is not needed really, values get reset when user chooses and
      // navigating to the mode.
      // but it triggers HomeView to update, so keeping it for now.
      viewModel.reset()
      
      stopObservingStateChanges()
      NotificationCenter.default.removeObserver(self)
      
      if RPScreenRecorder.shared().isRecording {
         print("🛑recording stopped")
         RPScreenRecorder.shared().stopRecording()
      }
   }
   
   // MARK: - Public Methods
   
   /// Sets the hoop region manually.
   ///
   /// It gets called when hoop selection goes from `inProgress` to `set` state and user confirms the selection.
   func setHoop() async {
      self.hoopBoundingBox.reset()
      
      let selectedArea = manualHoopAreaSelectorView.getSelectedArea()
      self.hoopRegion = selectedArea
      updateBoundingBox(hoopBoundingBox, withRect: selectedArea)
      hoopBoundingBox.borderColor = .green
      hoopBoundingBox.visionRect = cameraViewController.visionRectForViewRect(hoopBoundingBox.frame)
      manualHoopAreaSelectorView.isHidden = true
      
      // Reset values
      trajectoryView.resetPath()
      
      viewModel.lastShotMetrics = nil
      viewModel.playerStats.reset()
      
      await cameraViewController.restartVideo()
      
      gameManager.stateMachine.enter(GameManager.DetectedHoopState.self)
   }
   
   /// Sets the hoop region automatically in test mode.
   ///
   /// Rect of hoop in test mode video is calculated beforehand.
   /// - Warning: This method should only be called when `isTestMode` is true.
   func testModePresetHoop() {
      let visionRect = CGRect(x: 0.24952290076335876, y: 0.5932993803922153, width: 0.04818700834085016, height: 0.09838847774282367)
      let selectedArea = cameraViewController.viewRectForVisionRect(visionRect)
      
      self.hoopRegion = selectedArea
      updateBoundingBox(hoopBoundingBox, withRect: selectedArea)
      hoopBoundingBox.borderColor = .green
      hoopBoundingBox.visionRect = cameraViewController.visionRectForViewRect(hoopBoundingBox.frame)
      manualHoopAreaSelectorView.isHidden = true
      
      let point: CGPoint = .init(x: hoopBoundingBox.visionRect.minX, y: hoopBoundingBox.visionRect.midY)
      // HoopCenterPoint is used for showing Tip in SwiftUI view.
      viewModel.hoopCenterPoint = viewPointConverted(fromNormalizedContentsPoint: point)
      
      self.gameManager.stateMachine.enter(GameManager.DetectedHoopState.self)
   }
   
   /// Cancels the manual hoop selection process.
   ///
   /// It  gets called when hoop selection goes from`inProgress` to `none` state and user cancels the selection.
   func cancelManualHoopSelectionAction() async {
      hoopBoundingBox.isHidden = false
      manualHoopAreaSelectorView.isHidden = true
      
      // Reset values
      trajectoryView.resetPath()
      viewModel.lastShotMetrics = nil
      viewModel.playerStats.reset()
      
      await cameraViewController.restartVideo()
      
      if gameManager.stateMachine.currentState is GameManager.DetectingHoopState && hoopRegion.isEmpty == false {
         // there is already a set up hoop
         gameManager.stateMachine.enter(GameManager.DetectedHoopState.self)
      }
   }
   
   /// Starts the manual hoop selection process.
   ///
   /// It gets called when hoop selection goes from `none` to `inProgress` state.
   func inProgressManualHoopSelectionAction() {
      manualHoopAreaSelectorView.isHidden = false
      
      // Enter detecting hoop state
      gameManager.stateMachine.enter(GameManager.DetectingHoopState.self)
      
      // Pause video if there's any
      cameraViewController.pauseVideo()
      
      // Reset values
      // Resetting `detectTrajectoryRequest` too, because when restarting video again, previous results get mixed with new ones
      trajectoryView.resetPath()
      detectTrajectoryRequest = VNDetectTrajectoriesRequest(frameAnalysisSpacing: .zero, trajectoryLength: GameConstants.trajectoryLength)
   }
   
   func finishGame() {
      gameManager.stateMachine.enter(GameManager.ShowSummaryState.self)
   }
   
   // MARK: - Private Methods
   
   @objc private func playerDidFinishPlaying() {
      gameManager.stateMachine.enter(GameManager.ShowSummaryState.self)
   }
   
   private func updateBoundingBox(
      _ boundingBox: BoundingBoxView,
      withRect rect: CGRect?
   ) {
      boundingBox.frame = rect!
      boundingBox.performTransition((rect == nil ? .fadeOut : .fadeIn), duration: 0.1)
   }
   
   private func updateBoundingBox(
      _ boundingBox: BoundingBoxView,
      withViewRect rect: CGRect?,
      visionRect: CGRect
   ) {
      DispatchQueue.main.async {
         boundingBox.frame = rect ?? .zero
         boundingBox.visionRect = visionRect
         if rect == nil {
            boundingBox.performTransition(.fadeOut, duration: 0.1)
         } else {
            boundingBox.performTransition(.fadeIn, duration: 0.1)
         }
      }
   }
   
   private func humanBoundingBox(for observation: VNHumanBodyPoseObservation) -> CGRect {
      var box = CGRect.zero
      var normalizedBoundingBox = CGRect.null
      // Process body points only if the confidence is high.
      guard observation.confidence > GameConstants.bodyPoseDetectionMinConfidence, let points = try? observation.recognizedPoints(forGroupKey: .all) else {
         return box
      }
      // Only use point if human pose joint was detected reliably.
      for (_, point) in points where point.confidence > GameConstants.bodyPoseRecognizedPointMinConfidence {
         normalizedBoundingBox = normalizedBoundingBox.union(CGRect(origin: point.location, size: .zero))
      }
      if !normalizedBoundingBox.isNull {
         box = normalizedBoundingBox
      }
      // Fetch body joints from the observation and overlay them on the player.
      let joints = getBodyJointsFor(observation: observation)
      DispatchQueue.main.async {
         self.jointSegmentView.joints = joints
      }
      
      
      if gameManager.stateMachine.currentState is GameManager.TrackShotsState {
         viewModel.playerStats.storeBodyPoseObservation(observation)
         if trajectoryView.inFlight {
            trajectoryInFlightPoseObservations += 1
         }
      }
      return box
   }
   
   private func setUIElements() {
      manualHoopAreaSelectorView = .init(frame: view.bounds)
      manualHoopAreaSelectorView.isHidden = true
      
      playerBoundingBox.borderColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
      playerBoundingBox.backgroundOpacity = 0
      playerBoundingBox.isHidden = true
      view.addSubview(playerBoundingBox)
      view.addSubview(jointSegmentView)
      view.addSubview(trajectoryView)
      view.addSubview(manualHoopAreaSelectorView)
      view.addSubview(hoopSafeAreaView)
   }
   
   private func setupHoopBoundingBox() {
      hoopBoundingBox.borderColor = #colorLiteral(red: 1, green: 0.5763723254, blue: 0, alpha: 1)
      hoopBoundingBox.borderWidth = 2
      hoopBoundingBox.borderCornerRadius = 4
      hoopBoundingBox.borderCornerSize = 0
      hoopBoundingBox.backgroundOpacity = 0.45
      hoopBoundingBox.isHidden = true
      
      // Edit hoop context menu
      let interaction = UIContextMenuInteraction(delegate: self)
      hoopBoundingBox.addInteraction(interaction)
      hoopBoundingBox.isUserInteractionEnabled = true
      
      view.addSubview(hoopBoundingBox)
      view.bringSubviewToFront(hoopBoundingBox)
   }
   
   private func configureCameraView() {
      
      cameraViewController.outputDelegate = self
      // Set up the video layers.
      cameraViewController.view.frame = view.bounds
      addChild(cameraViewController)
      cameraViewController.beginAppearanceTransition(true, animated: true)
      view.addSubview(cameraViewController.view)
      cameraViewController.endAppearanceTransition()
      cameraViewController.didMove(toParent: self)
      
      view.bringSubviewToFront(hoopBoundingBox)
      view.bringSubviewToFront(playerBoundingBox)
      view.bringSubviewToFront(jointSegmentView)
      view.bringSubviewToFront(trajectoryView)
      view.bringSubviewToFront(manualHoopAreaSelectorView)
      view.bringSubviewToFront(hoopSafeAreaView)
      
      do {
         if recordedVideoSource != nil {
            // Start reading the video.
            cameraViewController.startReadingAsset(recordedVideoSource!)
            NotificationCenter.default
               .addObserver(self,
                            selector: #selector(playerDidFinishPlaying),
                            name: .AVPlayerItemDidPlayToEndTime,
                            object: cameraViewController.videoRenderView.player!.currentItem
               )
         } else {
            // Start live camera capture.
            try cameraViewController.setupAVSession()
         }
         
         RPScreenRecorder.shared().startRecording { err in
            if let err {
               self.viewModel.isRecordingPermissionDenied = true
            }
         }
      } catch {
         AppError.display(error, inViewController: self)
      }
   }
}

// MARK: - Trajectory stuff

extension ContentAnalysisViewController {
   private func detectTrajectory(
      visionHandler: VNImageRequestHandler,
      _ controller: CameraViewController
   ) {
      DispatchQueue.main.async {
         // Get the frame of rendered view
         let normalizedFrame = CGRect(x: 0, y: 0, width: 1, height: 1)
         self.jointSegmentView.frame = controller.viewRectForVisionRect(normalizedFrame)
         self.trajectoryView.frame = controller.viewRectForVisionRect(normalizedFrame)
      }
      // Perform the trajectory request in a separate dispatch queue.
      trajectoryQueue.async {
         do {
            try visionHandler.perform([self.detectTrajectoryRequest])
            if let results = self.detectTrajectoryRequest.results {
               DispatchQueue.main.async {
                  self.processTrajectoryObservations(controller, results)
               }
            }
         } catch {
            print("error", error.localizedDescription)
         }
      }
   }
   
   private func processTrajectoryObservations(
      _ controller: CameraViewController,
      _ results: [VNTrajectoryObservation]
   ) {
      if self.trajectoryView.inFlight && results.count < 1 {
         // The trajectory is already in flight but VNDetectTrajectoriesRequest doesn't return any trajectory observations.
         self.noObservationFrameCount += 1
         if self.noObservationFrameCount > 10 {
            var trajectoryPoints = NSOrderedSet(array: trajectoryView.uniquePoints).map({ $0 as! CGPoint })
            trajectoryPoints = trajectoryPoints.filter { hoopSafeAreaView.frame.contains($0) }
            
            shotCompletedAction(controller, trajectoryPoints)
         }
      } else {
         for path in results where path.confidence > GameConstants.trajectoryDetectionMinConfidence {
            
            let viewPoints = path.detectedPoints.map { controller.viewPointForVisionPoint($0.location) }
            
            guard let startX = viewPoints.first?.x,
                  let endX = viewPoints.last?.x else { return }
            
            let isTrajectoryDifferencePositive = endX - startX > 0
            let isPlayerHoopDifferencePositive = hoopRegion.midX - playerBoundingBox.frame.midX > 0
            
            // Check if the trajectory is on the right direction.
            if isTrajectoryDifferencePositive != isPlayerHoopDifferencePositive {
               // Trajectory is not in the right direction.
               trajectoryView.resetPath()
               return
            }
            
            // Checks if there is at least one point above the hoop.
            if viewPoints.first!.y > hoopRegion.maxY,
               viewPoints.last!.y > hoopRegion.maxY {
               // Trajectory starts and ends below the hoop, ignore it.
               // We are not resetting the path here,
               // because it ends up resetting whole trajectory.
               // We are also checking this condition in
               // shotCompletedAction method.
               return
            }
            
            trajectoryView.duration = path.timeRange.duration.seconds
            trajectoryView.points = path.detectedPoints
            trajectoryView.uniquePoints.append(contentsOf: viewPoints)
            trajectoryView.performTransition(.fadeIn, duration: 0.25)
            noObservationFrameCount = 0
         }
      }
   }
   
   private func showAllTrajectories() {
      for (index, path) in viewModel.playerStats.shotPaths.enumerated() {
         let trajectoryView = TrajectoryView(frame: view.bounds)
         trajectoryView.frame = cameraViewController.viewRectForVisionRect(.init(x: 0, y: 0, width: 1, height: 1))
         view.addSubview(trajectoryView)
         
         let isShotWentIn = viewModel.playerStats.shotResults[index] == .score
         trajectoryView.addPath(path, color: isShotWentIn ? .green : .red)
         view.bringSubviewToFront(trajectoryView)
      }
   }
}

// MARK: - Detect player stuff

extension ContentAnalysisViewController {
   private func detectPlayer(
      visionHandler: VNImageRequestHandler,
      _ controller: CameraViewController
   ) {
      do {
         try visionHandler.perform([detectPlayerRequest])
         if let result = detectPlayerRequest.results?.first {
            let box = humanBoundingBox(for: result)
            let boxView = playerBoundingBox
            DispatchQueue.main.async {
               let inset: CGFloat = -20.0
               let viewRect = controller.viewRectForVisionRect(box).insetBy(dx: inset, dy: inset)
               self.updateBoundingBox(boxView, withRect: viewRect)
               if !self.playerDetected && !boxView.isHidden {
                  self.gameManager.stateMachine.enter(GameManager.DetectedPlayerState.self)
               }
            }
         }
      } catch {
         print("error", error.localizedDescription)
      }
   }
   
   func hidePlayerBoundingBox() {
      DispatchQueue.main.async {
         if !self.playerBoundingBox.isHidden {
            self.playerBoundingBox.isHidden = true
            self.jointSegmentView.resetView()
         }
      }
   }
}

// MARK: -

extension ContentAnalysisViewController {
   private func updatePlayerStats(
      _ controller: CameraViewController,
      shotResult: ShotResult
   ) {
      // Compute the speed in mph
      let speed = round(trajectoryView.speed * gameManager.pointToMeterMultiplier * 2.24 * 100) / 100
      let releaseAngle = viewModel.playerStats.getReleaseAngle()
      
      let lastShotMetrics = ShotMetrics(
         shotResult: shotResult,
         speed: speed,
         releaseAngle: releaseAngle
      )
      viewModel.lastShotMetrics = lastShotMetrics
      
      viewModel.playerStats.storeShotPath(trajectoryView.fullTrajectory.cgPath)
      viewModel.playerStats.storeShotSpeed(speed)
      viewModel.playerStats.storeReleaseAngle(releaseAngle)
      viewModel.playerStats.adjustMetrics(isShotWentIn: shotResult == .score)
      viewModel.playerStats.storeShotResult(lastShotMetrics.shotResult)
      
      gameManager.stateMachine.enter(GameManager.ShotCompletedState.self)
   }
   
   private func shotCompletedAction(
      _ controller: CameraViewController,
      _ trajectoryPoints: [CGPoint]
   ) {
      let startPointX = trajectoryPoints.first!.x
      let endPointX = trajectoryPoints.last!.x
      let isStartPointOnLeftSideOfHoop = startPointX < hoopRegion.minX
      
      if trajectoryPoints.first!.y > hoopRegion.maxY,
         trajectoryPoints.last!.y > hoopRegion.maxY {
         // Trajectory starts and ends below the hoop, ignore it.
         trajectoryView.resetPath()
         return
      }
      
      var shotResult: ShotResult = .miss(.none)
      
      if let _ = trajectoryPoints.first(where: { hoopRegion.contains($0) }) {
         if isStartPointOnLeftSideOfHoop,
            let oppositeSidePoint = trajectoryPoints.first(where: { $0.x > hoopRegion.maxX }),
            oppositeSidePoint.y < hoopRegion.minY {
            // The ball goes from left to right "goes inside the hoop", but bounces back to the right side.
            // It happens because of VNDetectTrajectoryRequest does not work perfect
            // and draws wrong points.
            shotResult = .miss(.none)
         } else if !isStartPointOnLeftSideOfHoop,
                   let oppositeSidePoint = trajectoryPoints.first(where: { $0.x < hoopRegion.minX }),
                   oppositeSidePoint.y < hoopRegion.minY {
            // The ball goes from right to left "goes inside the hoop", but bounces back to the left side.
            // It happens because of VNDetectTrajectoryRequest does not work perfect
            // and draws wrong points.
            shotResult = .miss(.none)
         } else {
            shotResult = .score
         }
         
      } else if isStartPointOnLeftSideOfHoop,
                let oppositeSidePoint = trajectoryPoints.first(where: { $0.x > hoopRegion.maxX }),
                oppositeSidePoint.y < hoopRegion.minY {
         // The ball goes from left to right hits the rim, but bounces back to the right side.
         shotResult = .miss(.none)
      } else if !isStartPointOnLeftSideOfHoop,
                let oppositeSidePoint = trajectoryPoints.first(where: { $0.x < hoopRegion.minX }),
                oppositeSidePoint.y < hoopRegion.minY {
         // The ball goes from right to left hits the rim, but bounces back to the left side.
         shotResult = .miss(.none)
      }
      else if (startPointX < hoopRegion.minX && endPointX > hoopRegion.maxX) || (startPointX > hoopRegion.maxX && endPointX < hoopRegion.minX) {
         shotResult = .miss(.long)
      } else if isStartPointOnLeftSideOfHoop == (endPointX < hoopRegion.minX) {
         shotResult = .miss(.short)
      }
      
      updatePlayerStats(controller, shotResult: shotResult)
      trajectoryView.resetPath()
   }
}

// MARK: - Game state

extension ContentAnalysisViewController: GameStateChangeObserver {
   func gameManagerDidEnter(state: GameManager.State, from previousState: GameManager.State?) {
      print("stage", state)
      switch state {
      case is GameManager.DetectingHoopState where isTestMode:
         testModePresetHoop()
         
         Task {
            await EditHoopTip.viewAppearCount.donate()
         }
      case is GameManager.DetectingHoopState:
         viewModel.setupGuideLabel = "Set Hoop"
      case is GameManager.DetectedPlayerState:
         playerBoundingBox.performTransition(.fadeOut, duration: 1.0)
         viewModel.setupGuideLabel = "All Good"
         viewModel.setupStateModel.playerDetected = true
         gameManager.stateMachine.enter(GameManager.TrackShotsState.self)
      case is GameManager.TrackShotsState:
         trajectoryView.roi = cameraViewController.viewRectForVisionRect(.init(x: 0, y: 0.5, width: 1, height: 0.5))
         
         // once it's entered to track shot state
         // trajectory view seems to become on top of hoopbounding box
         // which leads to not detection of tap gestures
         //
         // happens when playing video not live camera
         // don't have time to debug it too, will see
         view.bringSubviewToFront(hoopBoundingBox)
      case is GameManager.DetectedHoopState:
         viewModel.setupGuideLabel = "Detecting Player"
         viewModel.setupStateModel.hoopDetected = true
         
         if playerDetected {
            gameManager.stateMachine.enter(GameManager.TrackShotsState.self)
         } else {
            gameManager.stateMachine.enter(GameManager.DetectingPlayerState.self)
         }
      case is GameManager.ShotCompletedState:
         viewModel.playerStats.resetPoseObservations()
         trajectoryInFlightPoseObservations = 0
         
         if isTestMode && viewModel.playerStats.shotCount == 2 {
            EditHoopTip.showTip = true
         }
         
         self.gameManager.stateMachine.enter(GameManager.TrackShotsState.self)
      case is GameManager.ShowSummaryState:
         // stop camera session if there's any
         cameraViewController.stopCameraSession()
         
         // When video ends, if there is still a trajectory on screen, handle it.
         if !trajectoryView.fullTrajectory.isEmpty {
            let trajectoryPoints = NSOrderedSet(array: trajectoryView.uniquePoints)
               .map({ $0 as! CGPoint })
               .filter { hoopSafeAreaView.frame.contains($0) }
            
            shotCompletedAction(cameraViewController, trajectoryPoints)
         }
         
         hoopBoundingBox.isHidden = true
         showAllTrajectories()
         RPScreenRecorder.shared().stopRecording { [weak self] preview, err in
            guard let self else { return }
            presentSummaryView(previewVC: preview)
         }
      default:
         break
      }
   }
}

// MARK: - Summary View Presentation

extension ContentAnalysisViewController {
   private func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
      previewController.dismiss(animated: true)
   }
   
   private func presentSummaryView(previewVC: RPPreviewViewController?) {
      let newOverlay = UIHostingController(
         rootView: SummaryView(
            previewVC: previewVC,
            playerStats: viewModel.playerStats
         )
      )
      newOverlay.view.frame = self.view.bounds
      newOverlay.view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
      
      self.addChild(newOverlay)
      newOverlay.beginAppearanceTransition(true, animated: true)
      self.view.addSubview(newOverlay.view)
      newOverlay.endAppearanceTransition()
      newOverlay.didMove(toParent: self)
   }
   
   // For testing purposes
   private func presentMockSummaryView(previewVC: RPPreviewViewController) {
      let newOverlay = UIHostingController(
         rootView: SummaryView(
            previewVC: previewVC,
            makesCount: 5,
            attemptsCount: 12,
            mostMissReason: "Short",
            avgReleaseAngle: 90,
            avgBallSpeed: 10
         )
      )
      newOverlay.view.frame = self.view.bounds
      newOverlay.view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
      
      self.addChild(newOverlay)
      newOverlay.beginAppearanceTransition(true, animated: true)
      self.view.addSubview(newOverlay.view)
      newOverlay.endAppearanceTransition()
      newOverlay.didMove(toParent: self)
   }
}

// MARK: - Context Menu

extension ContentAnalysisViewController: UIContextMenuInteractionDelegate {
   func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
      UIContextMenuConfiguration(
         identifier: nil,
         previewProvider: nil,
         actionProvider: { suggestedActions in
            let editAction = UIAction(
               title: NSLocalizedString("Edit Hoop",comment: ""),
               image: UIImage(systemName: "pencil")
            ) { action in
               self.viewModel.manualHoopSelectorState = .inProgress
               self.hoopBoundingBox.isHidden = true
            }
            
            return UIMenu(title: "", children: [editAction])
         }
      )
   }
}

extension ContentAnalysisViewController: CameraViewControllerOutputDelegate {
   func cameraViewController(
      _ controller: CameraViewController,
      didReceiveBuffer buffer: CMSampleBuffer,
      orientation: CGImagePropertyOrientation
   ) {
      if gameManager.pointToMeterMultiplier.isNaN, !hoopRegion.isEmpty {
         do {
            try setPointToMeterMultiplier(controller, buffer, orientation)
         } catch {
            print("detect hoop contours error", error)
         }
      }
      
      let visionHandler = VNImageRequestHandler(cmSampleBuffer: buffer, orientation: orientation, options: [:])
      if gameManager.stateMachine.currentState is GameManager.TrackShotsState {
         detectTrajectory(visionHandler: visionHandler, controller)
      }
      
      if !(self.trajectoryView.inFlight && self.trajectoryInFlightPoseObservations >= GameConstants.maxTrajectoryInFlightPoseObservations) {
         detectPlayer(visionHandler: visionHandler, controller)
      } else {
         hidePlayerBoundingBox()
      }
   }
   
   /// Calculates the point-to-meter multiplier and sets it to the `GameManager`.
   ///
   /// It is used for calculating the speed of the ball.
   private func setPointToMeterMultiplier(
      _ controller: CameraViewController,
      _ buffer: CMSampleBuffer,
      _ orientation: CGImagePropertyOrientation
   ) throws {
      let visionHandler = VNImageRequestHandler(cmSampleBuffer: buffer, orientation: orientation, options: [:])
      let contoursRequest = VNDetectContoursRequest()
      contoursRequest.contrastAdjustment = 1.6
      contoursRequest.regionOfInterest = hoopBoundingBox.visionRect
      try visionHandler.perform([contoursRequest])
      if let result = contoursRequest.results?.first as? VNContoursObservation {
         let hoopPath = result.normalizedPath
         
         DispatchQueue.main.sync {
            // Save hoop region
            hoopRegion = hoopBoundingBox.frame
            gameManager.hoopRegion = hoopBoundingBox.frame
            // Calculate hoop length based on the bounding box of the edge.
            let edgeNormalizedBB = hoopPath.boundingBox
            // Convert normalized bounding box size to points.
            let edgeSize = CGSize(width: edgeNormalizedBB.width * hoopBoundingBox.frame.width,
                                  height: edgeNormalizedBB.height * hoopBoundingBox.frame.height)
            
            let hoopLength = hypot(edgeSize.width, edgeSize.height)
            self.gameManager.pointToMeterMultiplier = GameConstants.hoopLength / Double(hoopLength)
         }
      }
   }
}
