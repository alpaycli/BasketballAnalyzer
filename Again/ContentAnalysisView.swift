//
//  ContentAnalysisViewController.swift
//  PlaygroundExploration
//
//  Created by Alpay Calalli on 18.12.24.
//

import ReplayKit
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
    let isTestMode: Bool
    @Bindable var viewModel: ContentViewModel
    
    func makeUIViewController(context: Context) -> ContentAnalysisViewController {
        let vc = ContentAnalysisViewController(
            recordedVideoSource: isTestMode ? getTestVideo() : recordedVideoSource,
            isTestMode: isTestMode,
            viewModel: viewModel,
            delegate: context.coordinator,
            cameraVCDelegate: context.coordinator
        )
        
        context.coordinator.vc = vc
        
        return vc
    }
    
    func updateUIViewController(_ uiViewController: ContentAnalysisViewController, context: Context) {
        print("updateUIViewController updated", viewModel.manualHoopSelectorState)
//        if uiViewController.delegate == nil {
//            uiViewController.delegate = context.coordinator
//        }
        
        if viewModel.isFinishButtonPressed {
            uiViewController.finishGame()
        }
        
        switch viewModel.manualHoopSelectorState {
        case .none:
            Task { await uiViewController.cancelManualHoopSelectionAction() }
        case .inProgress:
            uiViewController.inProgressManualHoopSelectionAction()
        case .set:
            Task { await uiViewController.setHoopRegion() }
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
    var viewModel: ContentViewModel!
    var isTestMode: Bool!
    
    var recordedVideoSource: AVAsset?
    
    // MARK: - Views
    
    private var cameraViewController = CameraViewController()
    private var trajectoryView = TrajectoryView()
    let hoopBoundingBox = BoundingBoxView()
    private let playerBoundingBox = BoundingBoxView()
    private let jointSegmentView = JointSegmentView()
    
    var manualHoopAreaSelectorView: AreaSelectorView!
    private var hoopRegion: CGRect = .zero {
        didSet {
            hoopSafeAreaView = UIView(frame: hoopRegion.inset(by: .init(top: -100, left: -100, bottom: -50, right: -100)))
        }
    }
    private var hoopSafeAreaView = UIView(frame: .zero)
    
    private var trajectoryInFlightPoseObservations = 0
    private var noObservationFrameCount = 0
    
    // MARK: - Requests
    
    private let detectPlayerRequest = VNDetectHumanBodyPoseRequest()
    private lazy var detectTrajectoryRequest: VNDetectTrajectoriesRequest! =
                        VNDetectTrajectoriesRequest(frameAnalysisSpacing: .zero, trajectoryLength: GameConstants.trajectoryLength)
//    private var hoopDetectionRequest: VNCoreMLRequest!
    
    // MARK: - States
    
    #warning("lazimsizdi, setup statede track olunur onsuz")
    private var playerDetected = false

    private var setupComplete = false
    private var showShotMetrics = false
    
    var setupStateModel = SetupStateModel()
    
    // MARK: - Others
    
    private let trajectoryQueue = DispatchQueue(label: "com.ActionAndVision.trajectory", qos: .userInteractive)
    
    private var poseObservations: [VNHumanBodyPoseObservation] = []
    
    private var playerStats = PlayerStats()
    private var lastShotMetrics = ShotMetrics()
    
    // MARK: - Init
    
    init(
        recordedVideoSource: AVAsset?,
        isTestMode: Bool,
        viewModel: ContentViewModel,
        delegate: ContentAnalysisVCDelegate,
        cameraVCDelegate: CameraViewControllerOutputDelegate
    ) {
        self.recordedVideoSource = recordedVideoSource
        self.isTestMode = isTestMode
        self.viewModel = viewModel
        self.delegate = delegate
        self.cameraViewController.outputDelegate = cameraVCDelegate
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupHoopDetectionRequest()
        startObservingStateChanges()
        setupHoopBoundingBox()
        setUIElements()
        configureView()
        
//        if isTestMode {
//            testModePresetHoop()
//            
//            Task {
//                await EditHoopTip.viewAppearCount.donate()
//            }
//        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        trajectoryView.roi = cameraViewController.viewRectForVisionRect(.init(x: 0, y: 0.5, width: 1, height: 0.5))
        
        if isTestMode {
            testModePresetHoop()
            
            Task {
                await EditHoopTip.viewAppearCount.donate()
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        viewModel.reset()
        
        stopObservingStateChanges()
        setupStateModel = .init()
        delegate?.updateSetupState(setupStateModel)
        NotificationCenter.default.removeObserver(self)
         
        if RPScreenRecorder.shared().isRecording {
            print("🛑recording stopped")
            RPScreenRecorder.shared().stopRecording()
        }
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
    
    func setHoopRegion() async {
        self.hoopBoundingBox.reset()
        
        let selectedArea = manualHoopAreaSelectorView.getSelectedArea()
        self.hoopRegion = selectedArea
        updateBoundingBox(hoopBoundingBox, withRect: selectedArea)
        hoopBoundingBox.borderColor = .green
        hoopBoundingBox.visionRect = cameraViewController.visionRectForViewRect(hoopBoundingBox.frame)
        manualHoopAreaSelectorView.isHidden = true

        // Reset values
        trajectoryView.resetPath()
        lastShotMetrics = .init()
        playerStats = .init()
        
        delegate?.showLastShowMetrics(metrics: lastShotMetrics, playerStats: playerStats)
        
        await cameraViewController.restartVideo()
        
        self.gameManager.stateMachine.enter(GameManager.DetectedHoopState.self)
    }
    
    /// For testing mode to speed up the judgement process.
    func testModePresetHoop() {
        // (0.24952290076335876, 0.5932993803922153, 0.04818700834085016, 0.09838847774282367)
        let visionRect = CGRect(x: 0.24952290076335876, y: 0.5932993803922153, width: 0.04818700834085016, height: 0.09838847774282367)
        let selectedArea = cameraViewController.viewRectForVisionRect(visionRect)
        
        self.hoopRegion = selectedArea
        updateBoundingBox(hoopBoundingBox, withRect: selectedArea)
        hoopBoundingBox.borderColor = .green
        hoopBoundingBox.visionRect = cameraViewController.visionRectForViewRect(hoopBoundingBox.frame)
        manualHoopAreaSelectorView.isHidden = true
        
        let point: CGPoint = .init(x: hoopBoundingBox.visionRect.minX, y: hoopBoundingBox.visionRect.midY)
        viewModel.hoopCenterPoint = viewPointConverted(fromNormalizedContentsPoint: point)
        
        self.gameManager.stateMachine.enter(GameManager.DetectedHoopState.self)
    }
    
    func cancelManualHoopSelectionAction() async {
        hoopBoundingBox.isHidden = false
        manualHoopAreaSelectorView.isHidden = true
        
        // Reset values
        trajectoryView.resetPath()
        lastShotMetrics = .init()
        playerStats = .init()
        
        delegate?.showLastShowMetrics(metrics: lastShotMetrics, playerStats: playerStats)
        
        await cameraViewController.restartVideo()
        
        if hoopRegion.isEmpty == false && gameManager.stateMachine.currentState is GameManager.DetectingHoopState {
            // there is already a setuped hoop
            gameManager.stateMachine.enter(GameManager.DetectedHoopState.self)
        }
    }
    
    func inProgressManualHoopSelectionAction() {
        manualHoopAreaSelectorView.isHidden = false
        
        // Enter detecting hoop state
        self.gameManager.stateMachine.enter(GameManager.DetectingHoopState.self)
        
        // Pause video if there's any
        cameraViewController.pauseVideo()
        
        // Reset values
        // Resetting `detectTrajectoryRequest` too, because when restarting video again, previous results get mixed with new ones
        self.trajectoryView.resetPath()
        detectTrajectoryRequest = VNDetectTrajectoriesRequest(frameAnalysisSpacing: .zero, trajectoryLength: GameConstants.trajectoryLength)
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
        view.addSubview(hoopSafeAreaView)
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
                    print("record error", err)
                    self.viewModel.isRecordingPermissionDenied = true
                }
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
        /* if hoopRegion.isEmpty, viewModel.manualHoopSelectorState == .none {
            delegate?.showSetupGuide("Detecting Hoop")
            do {
                try detectBoard(controller, buffer, orientation)
            } catch {
                print("detect board error", error.localizedDescription)
            }
        } */
        
        // It's needed for calculating the speed of the ball.
        if gameManager.pointToMeterMultiplier.isNaN, !hoopRegion.isEmpty {
            do {
                try setPointToMeterMultiplier(controller, buffer, orientation)
            } catch {
                print("detect hoop contours error", error)
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
    private func detectHoop(_ controller: CameraViewController, _ buffer: CMSampleBuffer, _ orientation: CGImagePropertyOrientation) throws {
        // This is where we detect the hoop.
        let visionHandler = VNImageRequestHandler(cmSampleBuffer: buffer, orientation: orientation, options: [:])
        try visionHandler.perform([viewModel.hoopDetectionRequest])
        var rect: CGRect?
        var visionRect = CGRect.null
        if let results = viewModel.hoopDetectionRequest.results as? [VNDetectedObjectObservation] {
            // Filter out classification results with low confidence
            let filteredResults = results
                .filter { $0.confidence > 0.70 }
            
            if !filteredResults.isEmpty {
                visionRect = filteredResults[0].boundingBox
                rect = controller.viewRectForVisionRect(visionRect)
            }
        }
        updateBoundingBox(hoopBoundingBox, withViewRect: rect, visionRect: visionRect)
        if rect != nil {
            gameManager.stateMachine.enter(GameManager.DetectedHoopState.self)
        }
    }
    
    private func setPointToMeterMultiplier(_ controller: CameraViewController, _ buffer: CMSampleBuffer, _ orientation: CGImagePropertyOrientation) throws {
        let visionHandler = VNImageRequestHandler(cmSampleBuffer: buffer, orientation: orientation, options: [:])
        let contoursRequest = VNDetectContoursRequest()
        contoursRequest.contrastAdjustment = 1.6 // the default contrast is 2.0 but in this case 1.6 gives us more reliable results
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

    private func setupHoopBoundingBox() {
        hoopBoundingBox.borderColor = #colorLiteral(red: 1, green: 0.5763723254, blue: 0, alpha: 1)
        hoopBoundingBox.borderWidth = 2
        hoopBoundingBox.borderCornerRadius = 4
        hoopBoundingBox.borderCornerSize = 0
        hoopBoundingBox.backgroundOpacity = 0.45
        hoopBoundingBox.isHidden = true
        
        let interaction = UIContextMenuInteraction(delegate: self)
        hoopBoundingBox.addInteraction(interaction)
        hoopBoundingBox.isUserInteractionEnabled = true
        
        view.addSubview(hoopBoundingBox)
        view.bringSubviewToFront(hoopBoundingBox)
    }
    
    private func setupHoopDetectionRequest() {
//        do {
//            // Create Vision request based on CoreML model
//            let model = try VNCoreMLModel(for: HoopDetectorBeta13x13(configuration: MLModelConfiguration()).model)
//            hoopDetectionRequest = VNCoreMLRequest(model: model)
//        } catch {
//            print("setupDetectHoopRequest error:", error.localizedDescription)
//        }
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
//                print("error", error.localizedDescription)
            }
        }
    }
    var isPlayerHoopDifferencePositive: Bool {
//        print("playerboundingbox.frame", playerBoundingBox.frame)
        return hoopRegion.midX - playerBoundingBox.frame.midX > 0
    }
    private func processTrajectoryObservations(_ controller: CameraViewController, _ results: [VNTrajectoryObservation]) {
        if self.trajectoryView.inFlight && results.count < 1 {
            // The trajectory is already in flight but VNDetectTrajectoriesRequest doesn't return any trajectory observations.
            self.noObservationFrameCount += 1
            if self.noObservationFrameCount > 10 {
                var trajectoryPoints = NSOrderedSet(array: trajectoryView.uniquePoints).map({ $0 as! CGPoint })
                trajectoryPoints = trajectoryPoints.filter { hoopSafeAreaView.frame.contains($0) }
                
                throwCompletedAction(controller, trajectoryPoints)
            }
        } else {
            for path in results where path.confidence > GameConstants.trajectoryDetectionMinConfidence {
                
                let viewPoints = path.detectedPoints.map { controller.viewPointForVisionPoint($0.location) }
                
                if viewPoints.first!.y > hoopRegion.maxY,
                   viewPoints.last!.y > hoopRegion.maxY {
                    print("trajectory asagida baslayib asagida bitir, bosver")
                    return
                }
                
                guard let start = path.detectedPoints.first?.x,
                      let end = path.detectedPoints.last?.x else { return }
                
                let isPositive = end - start > 0
                
                if isPositive != isPlayerHoopDifferencePositive {
//                    print("trajectory is on wrong direction")
                    return
                }
                
                self.trajectoryView.duration = path.timeRange.duration.seconds
                self.trajectoryView.points = path.detectedPoints
                trajectoryView.uniquePoints.append(contentsOf: viewPoints)
                self.trajectoryView.performTransition(.fadeIn, duration: 0.25)
                
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
//            print("error", error.localizedDescription)
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
    
    private func throwCompletedAction(_ controller: CameraViewController, _ trajectoryPoints: [CGPoint]) {
        guard !trajectoryPoints.isEmpty else {
            print("safe areada trajectory yoxdu")
            trajectoryView.resetPath()
            return
        }
        
        #warning("bu already yoxlanilir trajectory cekilen zaman")
        if trajectoryPoints.first!.y > hoopRegion.maxY && trajectoryPoints.last!.y > hoopRegion.maxY {
            print("trajectory asagida baslayib asagida bitir, bosver")
            trajectoryView.resetPath()
            return
        }
        
        let startPointX = trajectoryPoints.first!.x
        let isStartPointOnLeftSideOfHoop = startPointX < hoopRegion.minX
        let isPlayerOnLeftSideOfHoop = playerBoundingBox.frame.maxX < hoopRegion.minX
        
        if isStartPointOnLeftSideOfHoop != isPlayerOnLeftSideOfHoop {
            print("player and start of the trajectory is not on same side")
            trajectoryView.resetPath()
            return
        }
        
        var shotResult: ShotResult = .miss(.none)
        
        let endPointX = trajectoryPoints.last!.x
        let isEndPointOnLeftSideOfHoop = endPointX < hoopRegion.minX
        
//        print("trajectorypoints", trajectoryPoints.map { $0 })
//        print("hoopRegion", hoopRegion)
//        print("startPointX", startPointX)
//        print("endPointX", endPointX)
//        print("isStartPointOnLeftSideOfHoop", isStartPointOnLeftSideOfHoop)
//        print("isEndPointOnLeftSideOfHoop", isEndPointOnLeftSideOfHoop)
//        print("to compare", trajectoryPoints.first, trajectoryPoints.last)
//        print(":")
         
        if let _ = trajectoryPoints.first(where: { hoopRegion.contains($0) }) {
            if isStartPointOnLeftSideOfHoop,
               let oppositeSidePoint = trajectoryPoints.first(where: { $0.x > hoopRegion.maxX }),
               oppositeSidePoint.y < hoopRegion.minY {
//                print("saga dogru atilan top deyib qayidib")
                shotResult = .miss(.none)
            } else if !isStartPointOnLeftSideOfHoop,
                    let oppositeSidePoint = trajectoryPoints.first(where: { $0.x < hoopRegion.minX }),
                      oppositeSidePoint.y < hoopRegion.minY {
//                print("sola dogru atilan top deyib qayidib", oppositeSidePoint.y, hoopRegion.maxY, hoopRegion.minY)
                shotResult = .miss(.none)
            } else {
//                print("score")
                shotResult = .score
            }
            
        } else if (startPointX < hoopRegion.minX && endPointX > hoopRegion.maxX) || (startPointX > hoopRegion.maxX && endPointX < hoopRegion.minX) {
//            print("long")
            shotResult = .miss(.long)
        } else if isStartPointOnLeftSideOfHoop == isEndPointOnLeftSideOfHoop {
//            print("short")
            shotResult = .miss(.short)
        }
                
        updatePlayerStats(controller, shotResult: shotResult)
        
//        print(playerStats.totalScore, "makes from", playerStats.shotCount, "attempts")
//        print("-----")
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
        print("stage", state)
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
            trajectoryView.roi = cameraViewController.viewRectForVisionRect(.init(x: 0, y: 0.5, width: 1, height: 0.5))
            
            // once it's entered to track throw state
            // trajectory view seems to become on top of hoopbounding box
            // which leads to not detection of tap gestures
            //
            // happens when playing video not live camera
            // don't have time to debug it too, will see
            view.bringSubviewToFront(hoopBoundingBox)
        case is GameManager.DetectedHoopState:
            delegate?.showSetupGuide("Detecting Player")
            setupStateModel.hoopDetected = true
            delegate?.updateSetupState(setupStateModel)
            
            if playerDetected {
                self.gameManager.stateMachine.enter(GameManager.TrackThrowsState.self)
            } else {
                gameManager.stateMachine.enter(GameManager.DetectingPlayerState.self)
            }
        case is GameManager.ThrowCompletedState:
            delegate?.showLastShowMetrics(metrics: lastShotMetrics, playerStats: playerStats)

            poseObservations = []
            trajectoryInFlightPoseObservations = 0
            
            if isTestMode && playerStats.shotCount == 2 {
                EditHoopTip.showTip = true
            }
            
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
                var trajectoryPoints = NSOrderedSet(array: trajectoryView.uniquePoints)
                    .map({ $0 as! CGPoint })
                    .filter { hoopSafeAreaView.frame.contains($0) }
                
                throwCompletedAction(cameraViewController, trajectoryPoints)
            }
            hoopBoundingBox.isHidden = true
            
            showAllTrajectories()
            
            RPScreenRecorder.shared().stopRecording { [weak self] preview, err in
//                guard let preview,
//                      let self
//                else {
//                    print("no preview window"); return
//                }
                
                self?.presentSummaryView(previewVC: preview)
                
//                preview.modalPresentationStyle = .overFullScreen
//                preview.previewControllerDelegate = self
//                self.present(preview, animated: true)
            }
        default:
            break
        }
    }
    
    func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
        previewController.dismiss(animated: true)
    }
    
    func presentSummaryView(previewVC: RPPreviewViewController?) {
        let newOverlay = UIHostingController(rootView: SummaryView(previewVC: previewVC, playerStats: self.playerStats))
        newOverlay.view.frame = self.view.bounds
        self.addChild(newOverlay)
        newOverlay.beginAppearanceTransition(true, animated: true)
        newOverlay.view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        self.view.addSubview(newOverlay.view)
        newOverlay.endAppearanceTransition()
        newOverlay.didMove(toParent: self)
    }
}

struct RPPreviewView: UIViewControllerRepresentable {
    let previewVC: RPPreviewViewController
    init(previewVC: RPPreviewViewController) {
        self.previewVC = previewVC
    }
    
    
    func makeUIViewController(context: Context) -> RPPreviewViewController {
        previewVC.previewControllerDelegate = context.coordinator
        
        //                preview.modalPresentationStyle = .overFullScreen
        
        //                self.present(preview, animated: true)
        
        return previewVC
    }
    
    func updateUIViewController(_ uiViewController: RPPreviewViewController, context: Context) {
        
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, RPPreviewViewControllerDelegate {
        func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
            previewController.dismiss(animated: true)
        }
    }
}

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
