//
//  ContentAnalysisViewController.swift
//  PlaygroundExploration
//
//  Created by Alpay Calalli on 18.12.24.
//

import SwiftUI
import UIKit
import AVFoundation
import Vision

struct SetupStateModel {
    var hoopDetected = false
    var hoopContoursDetected = false
    var playerDetected = false
    
    /// Returns true if all setup steps are completed.
    var isAllDone: Bool {
        hoopDetected/* && hoopContoursDetected*/ && playerDetected
    }
}

struct ContentAnalysisView: UIViewControllerRepresentable {
    let recordedVideoSource: AVAsset?
    @Bindable var viewModel: ContentViewModel
    
    func makeUIViewController(context: Context) -> ContentAnalysisViewController {
        let vc = ContentAnalysisViewController()
        vc.setCameraVCDelegate(context.coordinator)
        vc.delegate = context.coordinator
        vc.recordedVideoSource = recordedVideoSource

        
        context.coordinator.vc = vc
        
        return vc
    }
    
    func updateUIViewController(_ uiViewController: ContentAnalysisViewController, context: Context) {
        print("updateUIViewController updated")
//        if uiViewController.delegate == nil {
//            uiViewController.delegate = context.coordinator
//        }
        
        switch viewModel.manualHoopSelectorState {
        case .none:
            uiViewController.manualHoopAreaSelectorView.isHidden = true
        case .inProgress:
            uiViewController.manualHoopAreaSelectorView.isHidden = false
        case .done:
            uiViewController.setHoopRegion()
            DispatchQueue.main.async {
                viewModel.manualHoopSelectorState = .none
            }
        }
        
        if viewModel.isFinishButtonPressed {
            uiViewController.finishGame()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CameraViewControllerOutputDelegate, ContentAnalysisVCDelegate {
        
        let parent: ContentAnalysisView
        var vc: ContentAnalysisViewController?
        
        init(_ parent: ContentAnalysisView) {
            self.parent = parent
        }
        
        func cameraViewController(_ controller: CameraViewController, didReceiveBuffer buffer: CMSampleBuffer, orientation: CGImagePropertyOrientation) {
            vc?.cameraVCDelegateAction(controller, didReceiveBuffer: buffer, orientation: orientation)
        }
        
        func showLastShowMetrics(metrics: ShotMetrics, playerStats: PlayerStats) {
            parent.viewModel.lastShotMetrics = metrics
            parent.viewModel.playerStats = playerStats
        }
        
        // not using
        func showSummary(stats: PlayerStats) {
//            parent.playerStats = stats
            // TODO: Fix
//            parent.gameEnded = true
        }
        
        func showSetupGuide(_ text: String?) {
            DispatchQueue.main.async {
                self.parent.viewModel.setupGuideLabel = text
            }
        }
        
        func updateSetupState(_ model: SetupStateModel) {
            DispatchQueue.main.async {
                self.parent.viewModel.setupStateModel = model
            }
        }
    }
}

protocol ContentAnalysisVCDelegate: AnyObject {
    func showLastShowMetrics(metrics: ShotMetrics, playerStats: PlayerStats)
    func showSummary(stats: PlayerStats)
    func showSetupGuide(_ text: String?)
    func updateSetupState(_ model: SetupStateModel)
}

class ContentAnalysisViewController: UIViewController {
    
    weak var delegate: ContentAnalysisVCDelegate?
    private let gameManager = GameManager.shared
    
    var recordedVideoSource: AVAsset?
    
    // MARK: - Views
    
    private var cameraViewController = CameraViewController()
    private var trajectoryView = TrajectoryView()
    private let boardBoundingBox = BoundingBoxView()
    private let playerBoundingBox = BoundingBoxView()
    private let jointSegmentView = JointSegmentView()
    
    var manualHoopAreaSelectorView: AreaSelectorView!
    private var hoopRegion: CGRect = .zero
    
    private var trajectoryInFlightPoseObservations = 0
    private var noObservationFrameCount = 0
    
    // MARK: - Requests
    
    private let detectPlayerRequest = VNDetectHumanBodyPoseRequest()
    private lazy var detectTrajectoryRequest: VNDetectTrajectoriesRequest! =
                        VNDetectTrajectoriesRequest(frameAnalysisSpacing: .zero, trajectoryLength: GameConstants.trajectoryLength)
    private var hoopDetectionRequest: VNCoreMLRequest!
    
    // MARK: - States
    
    private var hoopDetected = false
    private var playerDetected = false

    private var setupComplete = false
    private var showShotMetrics = false
    
    var setupStateModel = SetupStateModel()
    
    // MARK: - Others
    
    private let trajectoryQueue = DispatchQueue(label: "com.ActionAndVision.trajectory", qos: .userInteractive)
    
    private var poseObservations: [VNHumanBodyPoseObservation] = []
    
    private var playerStats = PlayerStats()
    private var lastShotMetrics = ShotMetrics()
    
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        startObservingStateChanges()
        setupHoopDetectionRequest()
        setupBoardBoundingBox()
        setUIElements()
        configureView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        trajectoryView.roi = view.frame
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopObservingStateChanges()
        setupStateModel = .init()
        delegate?.updateSetupState(setupStateModel)
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Init
    
//    init(recordedVideoSource: AVAsset? = nil) {
//        self.recordedVideoSource = recordedVideoSource
//        super.init(nibName: nil, bundle: nil)
//    }
//    
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
    
    // MARK: - Public Methods
    
    func setCameraVCDelegate(_ cameraVCDelegate: CameraViewControllerOutputDelegate) {
        self.cameraViewController.outputDelegate = cameraVCDelegate
    }
    
    func setHoopRegion() {
        let selectedArea = manualHoopAreaSelectorView.getSelectedArea()
        self.hoopRegion = selectedArea
        updateBoundingBox(boardBoundingBox, withRect: selectedArea)
        manualHoopAreaSelectorView.isHidden = false
        
        if let recordedVideoSource {
            cameraViewController.stopVideoPlayer()
            NotificationCenter.default.removeObserver(self)
            cameraViewController.startReadingAsset(recordedVideoSource)
            NotificationCenter.default
                .addObserver(self,
                selector: #selector(playerDidFinishPlaying),
                name: .AVPlayerItemDidPlayToEndTime,
                object: cameraViewController.videoRenderView.player!.currentItem
            )
        }
        
        gameManager.stateMachine.enter(GameManager.DetectedBoardState.self)
    }
    
    func finishGame() {
        gameManager.stateMachine.enter(GameManager.ShowSummaryState.self)
    }
    
    // MARK: - Private Methods
    
    @objc private func playerDidFinishPlaying() {
        print("video ended in viewcontroller")
        gameManager.stateMachine.enter(GameManager.ShowSummaryState.self)
    }
    
    private func updateBoundingBox(_ boundingBox: BoundingBoxView, withRect rect: CGRect?) {
        // Update the frame for player bounding box
        boundingBox.frame = rect!
        boundingBox.performTransition((rect == nil ? .fadeOut : .fadeIn), duration: 0.1)
    }
    
    private func updateBoundingBox(_ boundingBox: BoundingBoxView, withViewRect rect: CGRect?, visionRect: CGRect) {
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
        // Store the body pose observation in playerStats when the game is in TrackThrowsState.
        // We will use these observations for action classification once the throw is complete.
        if gameManager.stateMachine.currentState is GameManager.TrackThrowsState {
            storeBodyPoseObserarvations(observation)
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
//        gameStatusLabel.text = "Waiting for player"
        // Set throw type counters
//        underhandThrowView.throwType = .underhand
//        overhandThrowView.throwType = .overhand
//        underlegThrowView.throwType = .underleg
//        scoreLabel.attributedText = getScoreLabelAttributedStringForScore(0)
    }
    
    private func configureView() {
        
        // Set up the video layers.
        cameraViewController.view.frame = view.bounds
        addChild(cameraViewController)
        cameraViewController.beginAppearanceTransition(true, animated: true)
        view.addSubview(cameraViewController.view)
        cameraViewController.endAppearanceTransition()
        cameraViewController.didMove(toParent: self)
        
        view.bringSubviewToFront(boardBoundingBox)
        view.bringSubviewToFront(playerBoundingBox)
        view.bringSubviewToFront(jointSegmentView)
        view.bringSubviewToFront(trajectoryView)
        view.bringSubviewToFront(manualHoopAreaSelectorView)
        
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
        } catch {
            print("error--", error.localizedDescription)
//            AppError.display(error, inViewController: self)
        }
    }
}

// MARK: - CameraViewController delegate action

extension ContentAnalysisViewController {
    func cameraVCDelegateAction(_ controller: CameraViewController, didReceiveBuffer buffer: CMSampleBuffer, orientation: CGImagePropertyOrientation) {
        // video camera actions
        if hoopRegion.isEmpty {
            delegate?.showSetupGuide("Detecting Hoop")
            do {
                try detectBoard(controller, buffer, orientation)
            } catch {
                print("detect board error", error.localizedDescription)
            }
        }
        
        let visionHandler = VNImageRequestHandler(cmSampleBuffer: buffer, orientation: orientation, options: [:])
        if gameManager.stateMachine.currentState is GameManager.TrackThrowsState {
            detectTrajectory(visionHandler: visionHandler, controller)
        }
        
        if !(self.trajectoryView.inFlight && self.trajectoryInFlightPoseObservations >= GameConstants.maxTrajectoryInFlightPoseObservations) {
            detectPlayer(visionHandler: visionHandler, controller)
        } else {
            hidePlayerBoundingBox()
        }
    }
}

// MARK: - Detect hoop stuff

extension ContentAnalysisViewController {
    private func detectBoard(_ controller: CameraViewController, _ buffer: CMSampleBuffer, _ orientation: CGImagePropertyOrientation) throws {
        // This is where we detect the board.
        let visionHandler = VNImageRequestHandler(cmSampleBuffer: buffer, orientation: orientation, options: [:])
        try visionHandler.perform([hoopDetectionRequest])
        var rect: CGRect?
        var visionRect = CGRect.null
        if let results = hoopDetectionRequest.results as? [VNDetectedObjectObservation] {
            // Filter out classification results with low confidence
            let filteredResults = results
                .filter { $0.confidence > 0.70 }
            
            // Since the model is trained to detect only one object class (game board)
            // there is no need to look at labels. If there is at least one result - we got the board.
            if !filteredResults.isEmpty {
                visionRect = filteredResults[0].boundingBox
                rect = controller.viewRectForVisionRect(visionRect)
            }
        }
        updateBoundingBox(boardBoundingBox, withViewRect: rect, visionRect: visionRect)
        // If rect is nil we need to keep looking for the board, otherwise check the board placement
//        self.setupStage = (rect == nil) ? .detectingBoard : .detectingBoardPlacement
        
        try detectBoardContours(controller, buffer, orientation)
    }
    
    private func detectBoardContours(_ controller: CameraViewController, _ buffer: CMSampleBuffer, _ orientation: CGImagePropertyOrientation) throws {
        let visionHandler = VNImageRequestHandler(cmSampleBuffer: buffer, orientation: orientation, options: [:])
        let contoursRequest = VNDetectContoursRequest()
        contoursRequest.contrastAdjustment = 1.6 // the default contrast is 2.0 but in this case 1.6 gives us more reliable results
        contoursRequest.regionOfInterest = boardBoundingBox.visionRect
        try visionHandler.perform([contoursRequest])
        if let result = contoursRequest.results?.first as? VNContoursObservation {
            // Perform analysis of the top level contours in order to find board edge path and hole path.
            let boardPath = result.normalizedPath
            
            DispatchQueue.main.sync {
                // Save board region
                hoopRegion = boardBoundingBox.frame
                gameManager.boardRegion = boardBoundingBox.frame
//                print(gameManager.boardRegion)
                // Calculate board length based on the bounding box of the edge.
                let edgeNormalizedBB = boardPath.boundingBox
                // Convert normalized bounding box size to points.
                let edgeSize = CGSize(width: edgeNormalizedBB.width * boardBoundingBox.frame.width,
                                      height: edgeNormalizedBB.height * boardBoundingBox.frame.height)
                
                let hoopLength = hypot(edgeSize.width, edgeSize.height)
                self.gameManager.pointToMeterMultiplier = GameConstants.hoopLength / Double(hoopLength)

                
                let highlightPath = UIBezierPath(cgPath: boardPath)
                boardBoundingBox.visionPath = highlightPath.cgPath
                boardBoundingBox.borderColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 0.199807363)
                
                setupStateModel.hoopContoursDetected = true
                gameManager.stateMachine.enter(GameManager.DetectedBoardState.self)
            }
        }
    }

    private func setupBoardBoundingBox() {
        boardBoundingBox.borderColor = #colorLiteral(red: 1, green: 0.5763723254, blue: 0, alpha: 1)
        boardBoundingBox.borderWidth = 2
        boardBoundingBox.borderCornerRadius = 4
        boardBoundingBox.borderCornerSize = 0
        boardBoundingBox.backgroundOpacity = 0.45
        boardBoundingBox.isHidden = true
        view.addSubview(boardBoundingBox)
        view.bringSubviewToFront(boardBoundingBox)
    }
    
    private func setupHoopDetectionRequest() {
        do {
            // Create Vision request based on CoreML model
            let model = try VNCoreMLModel(for: HoopDetectorBeta13x13(configuration: MLModelConfiguration()).model)
            hoopDetectionRequest = VNCoreMLRequest(model: model)
        } catch {
            print("setupDetectHoopRequest error:", error.localizedDescription)
        }
    }
}

// MARK: - Trajectory stuff

extension ContentAnalysisViewController {
    private func detectTrajectory(visionHandler: VNImageRequestHandler, _ controller: CameraViewController) {
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
//                        print("*trajectoryresults.count", results.count)
                    DispatchQueue.main.async {
                        self.processTrajectoryObservations(controller, results)
                    }
                }
            } catch {
                print("error", error.localizedDescription)
            }
        }
    }
    
    private func processTrajectoryObservations(_ controller: CameraViewController, _ results: [VNTrajectoryObservation]) {
        if self.trajectoryView.inFlight && results.count < 1 {
            // The trajectory is already in flight but VNDetectTrajectoriesRequest doesn't return any trajectory observations.
            self.noObservationFrameCount += 1
            if self.noObservationFrameCount > GameConstants.noObservationFrameLimit {
                throwCompletedAction(controller)
            }
        } else {
            for path in results where path.confidence > GameConstants.trajectoryDetectionMinConfidence {
                // VNDetectTrajectoriesRequest has returned some trajectory observations.
                // Process the path only when the confidence is over 90%.
                self.trajectoryView.duration = path.timeRange.duration.seconds
                self.trajectoryView.points = path.detectedPoints
                self.trajectoryView.performTransition(.fadeIn, duration: 0.25)
                if !self.trajectoryView.fullTrajectory.isEmpty {
//                    self.updateTrajectoryRegions()
                    
                    // Hide the previous shot metrics once a new shot is detected.
                    if showShotMetrics {
                        showShotMetrics = false
                        print("resetting path")
                        trajectoryView.resetPath()
//                        delegate.showLastShowMetrics(metrics: nil)
                    }
                    
                    // Hide the previous throw metrics once a new throw is detected.
//                    if !self.dashboardView.isHidden {
//                        self.resetKPILabels()
//                    }
//                    if self.trajectoryView.isThrowComplete {
//                        print("*THROW COMPLETED")
//                        // Update the player statistics once the throw is complete.
//                        return throwCompletedAction(controller)
//                    }
                }
                self.noObservationFrameCount = 0
            }
        }
    }
     
    private func showAllTrajectories() {
        for (index, path) in playerStats.shotPaths.enumerated() {
            let trajectoryView = TrajectoryView(frame: view.bounds)
            trajectoryView.frame = cameraViewController.viewRectForVisionRect(.init(x: 0, y: 0, width: 1, height: 1))
            view.addSubview(trajectoryView)
            
            let isShotWentIn = playerStats.shotResults[index] == .score
            trajectoryView.addPath(path, color: isShotWentIn ? .green : .red)
            view.bringSubviewToFront(trajectoryView)
        }
    }
}

// MARK: - Detect player stuff

extension ContentAnalysisViewController {
    private func detectPlayer(visionHandler: VNImageRequestHandler, _ controller: CameraViewController) {
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
//                            self.gameStatusLabel.alpha = 0
//                            self.resetTrajectoryRegions()
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
    private func updatePlayerStats(_ controller: CameraViewController, shotResult: ShotResult) {
        // Compute the speed in mph
        // trajectoryView.speed is in points/second, convert that to meters/second by multiplying the pointToMeterMultiplier.
        // 1 meters/second = 2.24 miles/hour
        let speed = round(trajectoryView.speed * gameManager.pointToMeterMultiplier * 2.24 * 100) / 100
        // getReleaseAngle ve getLastJumpshotTypein playerStatda olmagi da menasizdi onsuz, baxariq.
        let releaseAngle = playerStats.getReleaseAngle(poseObservations: poseObservations)
        let jumpshotType = playerStats.getLastJumpshotType(poseObservations: poseObservations)
        
        lastShotMetrics = .init(
            shotResult: shotResult,
            speed: speed,
            releaseAngle: releaseAngle,
            jumpshotType: jumpshotType
        )
        
        playerStats.storeShotPath(trajectoryView.fullTrajectory.cgPath)
        playerStats.storeShotSpeed(speed)
        playerStats.storeReleaseAngle(releaseAngle)
        playerStats.adjustMetrics(isShotWentIn: shotResult == .score)
        playerStats.storeShotResult(lastShotMetrics.shotResult)
        
        self.gameManager.stateMachine.enter(GameManager.ThrowCompletedState.self)
    }
    
    private func throwCompletedAction(_ controller: CameraViewController) {
        let trajectoryPoints = trajectoryView.points
            .map { controller.viewPointForVisionPoint($0.location) }
        guard !trajectoryPoints.isEmpty else { return }
        
        var shotResult: ShotResult = .miss(.none)
        
        let startPointX = trajectoryPoints.first!.x
        let endPointX = trajectoryPoints.last!.x
        let isStartPointOnLeftSideOfHoop = startPointX < hoopRegion.minX
        let isEndPointOnLeftSideOfHoop = endPointX < hoopRegion.minX
        
        if let _ = trajectoryPoints.first(where: { hoopRegion.contains($0) }) {
            shotResult = .score
        } else if (startPointX < hoopRegion.minX && endPointX > hoopRegion.maxX) || (startPointX > hoopRegion.maxX && endPointX < hoopRegion.minX) {
            shotResult = .miss(.long)
        } else if isStartPointOnLeftSideOfHoop == isEndPointOnLeftSideOfHoop {
            shotResult = .miss(.short)
        }
        
        
        updatePlayerStats(controller, shotResult: shotResult)
        trajectoryView.resetPath()
    }
    
    private func storeBodyPoseObserarvations(_ observation: VNHumanBodyPoseObservation) {
        if poseObservations.count >= GameConstants.maxPoseObservations {
            poseObservations.removeFirst()
        }
        poseObservations.append(observation)
    }
}

// MARK: - Game state

extension ContentAnalysisViewController: GameStateChangeObserver {
    func gameManagerDidEnter(state: GameManager.State, from previousState: GameManager.State?) {
        switch state {
        case is GameManager.DetectedPlayerState:
            playerDetected = true
//            playerStats.reset()
            playerBoundingBox.performTransition(.fadeOut, duration: 1.0)
//            gameStatusLabel.text = "Go"
//            gameStatusLabel.perform(transitions: [.popUp, .popOut], durations: [0.25, 0.12], delayBetween: 1) {
            delegate?.showSetupGuide("All Good")
            setupStateModel.playerDetected = true
            delegate?.updateSetupState(setupStateModel)
                self.gameManager.stateMachine.enter(GameManager.TrackThrowsState.self)
//            }
        case is GameManager.TrackThrowsState:
            trajectoryView.roi = view.frame
        case is GameManager.DetectedBoardState:
//            setupStage =  .setupComplete
//            statusLabel.text = "Board Detected"
//            statusLabel.performTransitions([.popUp, .popOut], durations: [0.25, 0.12], delayBetween: 1.5) {
            delegate?.showSetupGuide("Detecting Player")
            setupStateModel.hoopDetected = true
            delegate?.updateSetupState(setupStateModel)
                self.gameManager.stateMachine.enter(GameManager.DetectingPlayerState.self)
//            }
        case is GameManager.ThrowCompletedState:
            delegate?.showLastShowMetrics(metrics: lastShotMetrics, playerStats: playerStats)
//            dashboardView.speed = lastThrowMetrics.releaseSpeed
//            dashboardView.animateSpeedChart()
//            playerStats.adjustMetrics(score: lastThrowMetrics.score, speed: lastThrowMetrics.releaseSpeed,
//                                      releaseAngle: lastThrowMetrics.releaseAngle, throwType: lastThrowMetrics.throwType)
//            playerStats.resetObservations() bunun yerine |
            poseObservations = []
            trajectoryInFlightPoseObservations = 0
            
//            print("after shot completed, here is lastShotMetrics:", lastShotMetrics)
//            print(playerStats.allReleaseAngles.count)
//            print("and player stats", playerStats)
//            print("poseobservations.count", poseObservations.count)
//            print("trajectoryview length", trajectoryView.points.count)
//            print("_-_-_-_")
//            self.updateKPILabels()
//
//            gameStatusLabel.text = lastThrowMetrics.score.rawValue > 0 ? "+\(lastThrowMetrics.score.rawValue)" : ""
//            gameStatusLabel.perform(transitions: [.popUp, .popOut], durations: [0.25, 0.12], delayBetween: 1) {
            #warning("maxShots can be changed to user's choice")
            #warning("yada yox, live camera da stop buttona basilanda game manageri swiftui viewda showsummary state e soxmaq olar ele, ve gostermek")
            #warning("ve video bitende")
//            if self.playerStats.shotCount == GameConstants.maxShots {
//                print("playerStats", playerStats.shotPaths.first)
//                self.gameManager.stateMachine.enter(GameManager.ShowSummaryState.self)
//            } else {
                self.gameManager.stateMachine.enter(GameManager.TrackThrowsState.self)
//            }
//            }
        case is GameManager.ShowSummaryState:
            // stop camera session if there's any
            cameraViewController.stopCameraSession()
            
            if !trajectoryView.fullTrajectory.isEmpty {
                throwCompletedAction(cameraViewController)
            }
            boardBoundingBox.isHidden = true
            
            showAllTrajectories()
        default:
            break
        }
    }
}
