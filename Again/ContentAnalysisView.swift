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

struct ContentAnalysisView: UIViewControllerRepresentable {
    let recordedVideoSource: AVAsset?
    @Binding var didScore: Bool
    
    func makeUIViewController(context: Context) -> ContentAnalysisViewController {
        let vc = ContentAnalysisViewController()
        vc.recordedVideoSource = recordedVideoSource
        
        context.coordinator.vc = vc
        
        return vc
    }
    
    func updateUIViewController(_ uiViewController: ContentAnalysisViewController, context: Context) {
        uiViewController.recordedVideoSource = recordedVideoSource
        uiViewController.setCameraVCDelegate(context.coordinator)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, CameraViewControllerOutputDelegate{
        let parent: ContentAnalysisView
        var vc: ContentAnalysisViewController?
        
        init(_ parent: ContentAnalysisView) {
            self.parent = parent
        }
        
        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            // live camera actions
        }
        
        func cameraViewController(_ controller: CameraViewController, didReceiveBuffer buffer: CMSampleBuffer, orientation: CGImagePropertyOrientation) {
            parent.didScore = vc?.cameraVCDelegateAction(controller, didReceiveBuffer: buffer, orientation: orientation) ?? false
        }
    }
}

class ContentAnalysisViewController: UIViewController {
    
//    // MARK: - Static Properties
//    static let segueDestinationId = "ShowAnalysisView"
//    
//    // MARK: - IBOutlets
//    @IBOutlet var closeButton: UIButton!
//
//    // MARK: - IBActions
//    @IBAction func closeRootViewTapped(_ sender: Any) {
//        dismiss(animated: true, completion: nil)
//    }
    
    // MARK: - Public Properties
    var recordedVideoSource: AVAsset?
    
    // MARK: - Private Properties
    private let gameManager = GameManager.shared
    
    private var cameraViewController = CameraViewController()
    private var trajectoryView = TrajectoryView()
    private let boardBoundingBox = BoundingBoxView()
    private let playerBoundingBox = BoundingBoxView()
    private let jointSegmentView = JointSegmentView()
    
    private var hoopRegion: CGRect = .zero
    
//    private var throwRegion = CGRect.null
//    private var targetRegion = CGRect.null
    
    private var trajectoryInFlightPoseObservations = 0
    private var noObservationFrameCount = 0
    
    private let bodyPoseDetectionMinConfidence: VNConfidence = 0.6
    private let trajectoryDetectionMinConfidence: VNConfidence = 0.9
    private let bodyPoseRecognizedPointMinConfidence: VNConfidence = 0.1
    
    var hoopDetected = false
    var playerDetected = false
    
    var didScore = false
    
    private var setupComplete = false
    private let detectPlayerRequest = VNDetectHumanBodyPoseRequest()
    private lazy var detectTrajectoryRequest: VNDetectTrajectoriesRequest! =
                        VNDetectTrajectoriesRequest(frameAnalysisSpacing: .zero, trajectoryLength: GameConstants.trajectoryLength)
    
    private var hoopDetectionRequest: VNCoreMLRequest!
    
    private let trajectoryQueue = DispatchQueue(label: "com.ActionAndVision.trajectory", qos: .userInteractive)
    
    // A dictionary that stores all trajectories.
    private var trajectoryDictionary: [String: [VNPoint]] = [:]
    private var poseObservations: [VNHumanBodyPoseObservation] = []
    
    private var playerStats = PlayerStats()
    private var lastShotMetrics = ShotMetrics()
    
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        startObservingStateChanges()
        setUIElements()
        configureView()
        setupBoardBoundingBox()
        setupDetectHoopRequest()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        trajectoryView.roi = view.frame
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
//        cameraViewController.stopCameraSession()
//        recordedVideoSource = nil
//        detectTrajectoryRequest = nil
//        detectPlayerRequest = nil
//        hoopDetectionRequest = nil
    }
    
    // MARK: - Public Methods
    
    func setCameraVCDelegate(_ cameraVCDelegate: CameraViewControllerOutputDelegate) {
        self.cameraViewController.outputDelegate = cameraVCDelegate
    }
    
    // MARK: - Private Methods
    
    private func updateBoundingBox(_ boundingBox: BoundingBoxView, withRect rect: CGRect?) {
        // Update the frame for player bounding box
        boundingBox.frame = rect ?? .zero
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
        guard observation.confidence > bodyPoseDetectionMinConfidence, let points = try? observation.recognizedPoints(forGroupKey: .all) else {
            return box
        }
        // Only use point if human pose joint was detected reliably.
        for (_, point) in points where point.confidence > bodyPoseRecognizedPointMinConfidence {
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
//        resetKPILabels()
        playerBoundingBox.borderColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        playerBoundingBox.backgroundOpacity = 0
        playerBoundingBox.isHidden = true
        view.addSubview(playerBoundingBox)
        view.addSubview(jointSegmentView)
        view.addSubview(trajectoryView)
//        gameStatusLabel.text = "Waiting for player"
        // Set throw type counters
//        underhandThrowView.throwType = .underhand
//        overhandThrowView.throwType = .overhand
//        underlegThrowView.throwType = .underleg
//        scoreLabel.attributedText = getScoreLabelAttributedStringForScore(0)
    }
    
    private func configureView() {
        
        // Set up the video layers.
//        cameraViewController = CameraViewController()
        cameraViewController.view.frame = view.bounds
        addChild(cameraViewController)
        cameraViewController.beginAppearanceTransition(true, animated: true)
        view.addSubview(cameraViewController.view)
        cameraViewController.endAppearanceTransition()
        cameraViewController.didMove(toParent: self)
        
        view.bringSubviewToFront(playerBoundingBox)
        view.bringSubviewToFront(jointSegmentView)
        view.bringSubviewToFront(trajectoryView)
//
        do {
            if recordedVideoSource != nil {
                // Start reading the video.
                cameraViewController.startReadingAsset(recordedVideoSource!)
            } else {
                // Start live camera capture.
                try cameraViewController.setupAVSession()
            }
        } catch {
            print("error--", error.localizedDescription)
//            AppError.display(error, inViewController: self)
        }
        
//        cameraViewController.outputDelegate = self
                
        // TODO: add close button
    }
    
    // This helper function is used to convert points returned by Vision to the video content rect coordinates.
    //
    // The video content rect (camera preview or pre-recorded video)
    // is scaled to fit into the view controller's view frame preserving the video's aspect ratio
    // and centered vertically and horizontally inside the view.
    //
    // Vision coordinates have origin at the bottom left corner and are normalized from 0 to 1 for both dimensions.
    //
    func viewPointForVisionPoint(_ visionPoint: CGPoint) -> CGPoint {
        let flippedPoint = visionPoint.applying(CGAffineTransform.verticalFlip)
        let viewPoint: CGPoint
        if recordedVideoSource != nil {
            viewPoint = self.viewPointConverted(fromNormalizedContentsPoint: flippedPoint)
        } else {
            viewPoint = .zero
//            viewPoint = cameraFeedView.viewPointConverted(fromNormalizedContentsPoint: flippedPoint)
        }
        return viewPoint
    }
    
    func viewPointConverted(fromNormalizedContentsPoint normalizedPoint: CGPoint) -> CGPoint {
        let videoRect = view.bounds
        let convertedPoint = CGPoint(x: videoRect.origin.x + normalizedPoint.x * videoRect.width,
                                     y: videoRect.origin.y + normalizedPoint.y * videoRect.height)
        return convertedPoint
    }
}

// MARK: - CameraViewController delegate action

extension ContentAnalysisViewController {
    func cameraVCDelegateAction(_ controller: CameraViewController, didReceiveBuffer buffer: CMSampleBuffer, orientation: CGImagePropertyOrientation) -> Bool {
        // video camera actions
        if hoopRegion.isEmpty {
        do {
            try detectBoard(controller, buffer, orientation)
        } catch {
            print("detect board error", error.localizedDescription)
        }
        }
        
        let visionHandler = VNImageRequestHandler(cmSampleBuffer: buffer, orientation: orientation, options: [:])
        if gameManager.stateMachine.currentState is GameManager.TrackThrowsState {
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
                            self.didScore = self.processTrajectoryObservations(controller, results)
                        }
                    }
                } catch {
                    print("error", error.localizedDescription)
                }
            }
        }
        
        if !(self.trajectoryView.inFlight && self.trajectoryInFlightPoseObservations >= GameConstants.maxTrajectoryInFlightPoseObservations) {
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
        } else {
            // Hide player bounding box
            DispatchQueue.main.async {
                if !self.playerBoundingBox.isHidden {
                    self.playerBoundingBox.isHidden = true
                    self.jointSegmentView.resetView()
                }
            }
        }
        
        return didScore
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
        // Show board placement guide only when using camera feed.
//        if gameManager.recordedVideoSource == nil {
//            let guideVisionRect = CGRect(x: 0.7, y: 0.3, width: 0.28, height: 0.3)
//            let guideRect = controller.viewRectForVisionRect(guideVisionRect)
//            updateBoundingBox(boardLocationGuide, withViewRect: guideRect, visionRect: guideVisionRect)
//        }
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

                
                let highlightPath = UIBezierPath(cgPath: boardPath)
                boardBoundingBox.visionPath = highlightPath.cgPath
                boardBoundingBox.borderColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 0.199807363)
                
                self.gameManager.stateMachine.enter(GameManager.DetectedBoardState.self)
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
    }
    
    private func setupDetectHoopRequest() {
        do {
            // Create Vision request based on CoreML model
            let model = try VNCoreMLModel(for: HoopDetectorBeta13x13(configuration: MLModelConfiguration()).model)
            hoopDetectionRequest = VNCoreMLRequest(model: model)
            
            // Since board is close to the side of a landscape image,
            // we need to set crop and scale option to scaleFit.
            // By default vision request will run on centerCrop.
//            hoopDetectionRequest.imageCropAndScaleOption = .scaleFit
            
//            guard let results = hoopDetectionRequest.results as? [VNRecognizedObjectObservation] else {
//                print("No results found.")
//                return
//            }
//
//            // Iterate through results
//            for observation in results {
//                // Access labels and confidence
//                let topLabel = observation.labels.first
//                if let label = topLabel {
//                    print("Detected: \(label.identifier), Confidence: \(label.confidence)")
//                }
//
//                // Access bounding box
//                print("Bounding Box: \(observation.boundingBox)")
//            }
        } catch {
            print("*****boundingbox/", error.localizedDescription)
        }
    }
}

// MARK: - Trajectory stuff

extension ContentAnalysisViewController {
    func processTrajectoryObservations(_ controller: CameraViewController, _ results: [VNTrajectoryObservation]) -> Bool {
        if self.trajectoryView.inFlight && results.count < 1 {
            // The trajectory is already in flight but VNDetectTrajectoriesRequest doesn't return any trajectory observations.
            self.noObservationFrameCount += 1
            if self.noObservationFrameCount > GameConstants.noObservationFrameLimit {
                return throwCompletedAction(controller)
            }
        } else {
            for path in results where path.confidence > trajectoryDetectionMinConfidence {
                // VNDetectTrajectoriesRequest has returned some trajectory observations.
                // Process the path only when the confidence is over 90%.
                self.trajectoryView.duration = path.timeRange.duration.seconds
                self.trajectoryView.points = path.detectedPoints
                self.trajectoryView.performTransition(.fadeIn, duration: 0.25)
                if !self.trajectoryView.fullTrajectory.isEmpty {
                    
//                    self.updateTrajectoryRegions()
                    
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
        return false
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
                self.gameManager.stateMachine.enter(GameManager.TrackThrowsState.self)
//            }
        case is GameManager.TrackThrowsState:
//            resetTrajectoryRegions()
            trajectoryView.roi = view.frame
        case is GameManager.DetectedBoardState:
//            setupStage =  .setupComplete
//            statusLabel.text = "Board Detected"
//            statusLabel.perform(transitions: [.popUp, .popOut], durations: [0.25, 0.12], delayBetween: 1.5) {
                self.gameManager.stateMachine.enter(GameManager.DetectingPlayerState.self)
//            }
        case is GameManager.ThrowCompletedState:
//            dashboardView.speed = lastThrowMetrics.releaseSpeed
//            dashboardView.animateSpeedChart()
//            playerStats.adjustMetrics(score: lastThrowMetrics.score, speed: lastThrowMetrics.releaseSpeed,
//                                      releaseAngle: lastThrowMetrics.releaseAngle, throwType: lastThrowMetrics.throwType)
//            playerStats.resetObservations() bunun yerine |
            poseObservations = []
            trajectoryInFlightPoseObservations = 0
            
            print("after shot completed, here is lastShotMetrics:", lastShotMetrics)
            print(playerStats.allReleaseAngles.count)
//            print("and player stats", playerStats)
//            print("poseobservations.count", poseObservations.count)
//            print("trajectoryview length", trajectoryView.points.count)
            print("_-_-_-_")
//            self.updateKPILabels()
//
//            gameStatusLabel.text = lastThrowMetrics.score.rawValue > 0 ? "+\(lastThrowMetrics.score.rawValue)" : ""
//            gameStatusLabel.perform(transitions: [.popUp, .popOut], durations: [0.25, 0.12], delayBetween: 1) {
//                if self.playerStats.throwCount == GameConstants.maxThrows {
//                    self.gameManager.stateMachine.enter(GameManager.ShowSummaryState.self)
//                } else {
                    self.gameManager.stateMachine.enter(GameManager.TrackThrowsState.self)
//                }
//            }
        default:
            break
        }
    }
}

// MARK: -

extension ContentAnalysisViewController {
    func updatePlayerStats(_ controller: CameraViewController, isShotWentIn isScore: Bool) {
        
        // Compute the speed in mph
        // trajectoryView.speed is in points/second, convert that to meters/second by multiplying the pointToMeterMultiplier.
        // 1 meters/second = 2.24 miles/hour
        let speed = round(trajectoryView.speed * gameManager.pointToMeterMultiplier * 2.24 * 100) / 100
        // getReleaseAngle ve getLastJumpshotTypein playerStatda olmagi da menasizdi onsuz, baxariq.
        let releaseAngle = playerStats.getReleaseAngle(poseObservations: poseObservations)
        let jumpshotType = playerStats.getLastJumpshotType(poseObservations: poseObservations)
        
        lastShotMetrics = .init(
            isScore: isScore,
            speed: speed,
            releaseAngle: releaseAngle,
            jumpshotType: jumpshotType
        )
        
        playerStats.storeShotPath(.init(rect: .zero, transform: .none)/*trajectoryView.fullTrajectory.cgPath*/)
        playerStats.storeShotSpeed(speed)
        playerStats.storeReleaseAngle(releaseAngle)
        playerStats.adjustMetrics(isShotWentIn: isScore)
        
        self.gameManager.stateMachine.enter(GameManager.ThrowCompletedState.self)
    }
    
    private func throwCompletedAction(_ controller: CameraViewController) -> Bool {
        let trajectoryPoints = trajectoryView.points
            .map { viewPointForVisionPoint($0.location) }
        let insideHoopBallLocation = trajectoryPoints.first(where: { hoopRegion.contains($0) })
        
        updatePlayerStats(controller, isShotWentIn: insideHoopBallLocation != nil)
        trajectoryView.resetPath()
        
        return insideHoopBallLocation != nil
    }
    
    func storeBodyPoseObserarvations(_ observation: VNHumanBodyPoseObservation) {
        if poseObservations.count >= GameConstants.maxPoseObservations {
            poseObservations.removeFirst()
        }
        poseObservations.append(observation)
    }
}

enum JumpshotType: String, CaseIterable {
    case underhand = "Underhand"
    case normal = "Normal"
    case none = "None"
}

struct ShotMetrics {
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
