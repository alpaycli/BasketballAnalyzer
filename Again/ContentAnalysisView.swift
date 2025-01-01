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
            vc?.cameraVCDelegateAction(controller, didReceiveBuffer: buffer, orientation: orientation)
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
    
    private var setupComplete = false
    private let detectPlayerRequest = VNDetectHumanBodyPoseRequest()
    private lazy var detectTrajectoryRequest: VNDetectTrajectoriesRequest! =
                        VNDetectTrajectoriesRequest(frameAnalysisSpacing: .zero, trajectoryLength: GameConstants.trajectoryLength)
    
    private var hoopDetectionRequest: VNCoreMLRequest!
    
    private let trajectoryQueue = DispatchQueue(label: "com.ActionAndVision.trajectory", qos: .userInteractive)
    
    // A dictionary that stores all trajectories.
    private var trajectoryDictionary: [String: [VNPoint]] = [:]
    
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
//        if gameManager.stateMachine.currentState is GameManager.TrackThrowsState {
//            playerStats.storeObservation(observation)
//            if trajectoryView.inFlight {
//                trajectoryInFlightPoseObservations += 1
//            }
//        }
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
    func cameraVCDelegateAction(_ controller: CameraViewController, didReceiveBuffer buffer: CMSampleBuffer, orientation: CGImagePropertyOrientation) {
        // video camera actions
        if hoopRegion.isEmpty {
            try? detectBoard(controller, buffer, orientation)
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
                        DispatchQueue.main.async   {
                            self.processTrajectoryObservations(controller, results)
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
            let filteredResults = results.filter { $0.confidence > 0.90 }
             
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
            let model = try VNCoreMLModel(for: HoopDetectorLight(configuration: MLModelConfiguration()).model)
            hoopDetectionRequest = VNCoreMLRequest(model: model)
            // Since board is close to the side of a landscape image,
            // we need to set crop and scale option to scaleFit.
            // By default vision request will run on centerCrop.
            hoopDetectionRequest.imageCropAndScaleOption = .scaleFit
        } catch {
            print("*****boundingbox/", error.localizedDescription)
        }
    }
}

// MARK: - Trajectory stuff

extension ContentAnalysisViewController {
    func processTrajectoryObservations(_ controller: CameraViewController, _ results: [VNTrajectoryObservation]) {
        if self.trajectoryView.inFlight && results.count < 1 {
            // The trajectory is already in flight but VNDetectTrajectoriesRequest doesn't return any trajectory observations.
            self.noObservationFrameCount += 1
            if self.noObservationFrameCount > GameConstants.noObservationFrameLimit {
                let pointSize: CGFloat = 10
                
                let finalBagLocation = viewPointForVisionPoint(trajectoryView.finalBagLocation)
                print("throwCompleted")
                print("score", hoopRegion.contains(finalBagLocation) ? "var✅" : "yox❌", hoopRegion, ".contains(", finalBagLocation, ")")
                
//                let hoopRegView = UIView(frame: .init(
//                    x: hoopRegion.midX - pointSize/2,
//                    y: hoopRegion.minY - pointSize/2,
//                    width: pointSize,
//                    height: pointSize
//                ))
//                hoopRegView.backgroundColor = UIColor.red.withAlphaComponent(0.8)
//                hoopRegView.layer.cornerRadius = pointSize/2  // Makes it circular
//                self.view.addSubview(hoopRegView)
//                                
                trajectoryView.resetPath()
                
                let trajectoryPoints = trajectoryView.points
                    .map { viewPointForVisionPoint($0.location) }
                
                
                for (index, point) in trajectoryPoints.enumerated() {
                    print("*", point.y, "should be smaller than", hoopRegion.minY)
                            let point = UIView(frame: CGRect(
                                x: point.x - pointSize/2,
                                y: point.y - pointSize/2,
                                width: pointSize,
                                height: pointSize
                            ))
                    point.backgroundColor = UIColor.red.withAlphaComponent(0.8)
                            point.layer.cornerRadius = pointSize/2  // Makes it circular
//                            self.view.addSubview(point)
                            
                }
                
                guard let aboveRimBallLocation = trajectoryPoints.last(where: { $0.y < hoopRegion.minY })
                else {
                    print("no above rim location")
                    return
                }
                
//                let aboveRimBallLocation = viewPointForVisionPoint(rawAboveRimBallLocation)
                
                let finalBallLocationView = UIView(frame: CGRect(
                    x: finalBagLocation.x - pointSize/2,
                    y: finalBagLocation.y - pointSize/2,
                    width: pointSize,
                    height: pointSize
                ))
                finalBallLocationView.backgroundColor = UIColor.blue.withAlphaComponent(0.8)
                finalBallLocationView.layer.cornerRadius = pointSize/2  // Makes it circular
                self.view.addSubview(finalBallLocationView)
                
                let aboveRimBallLocationView = UIView(frame: CGRect(
                    x: aboveRimBallLocation.x - pointSize/2,
                    y: aboveRimBallLocation.y - pointSize/2,
                    width: pointSize,
                    height: pointSize
                ))
                aboveRimBallLocationView.backgroundColor = UIColor.red.withAlphaComponent(0.8)
                aboveRimBallLocationView.layer.cornerRadius = pointSize/2  // Makes it circular
                self.view.addSubview(aboveRimBallLocationView)
                
                // Ending the throw as we don't see any observations in consecutive GameConstants.noObservationFrameLimit frames.
//                self.updatePlayerStats(controller)
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
//                        self.updatePlayerStats(controller)
//                        trajectoryView.resetPath()
//                    }
                }
                self.noObservationFrameCount = 0
            }
        }
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
        case is GameManager.ThrowCompletedState: break
//            dashboardView.speed = lastThrowMetrics.releaseSpeed
//            dashboardView.animateSpeedChart()
//            playerStats.adjustMetrics(score: lastThrowMetrics.score, speed: lastThrowMetrics.releaseSpeed,
//                                      releaseAngle: lastThrowMetrics.releaseAngle, throwType: lastThrowMetrics.throwType)
//            playerStats.resetObservations()
//            trajectoryInFlightPoseObservations = 0
//            self.updateKPILabels()
//
//            gameStatusLabel.text = lastThrowMetrics.score.rawValue > 0 ? "+\(lastThrowMetrics.score.rawValue)" : ""
//            gameStatusLabel.perform(transitions: [.popUp, .popOut], durations: [0.25, 0.12], delayBetween: 1) {
//                if self.playerStats.throwCount == GameConstants.maxThrows {
//                    self.gameManager.stateMachine.enter(GameManager.ShowSummaryState.self)
//                } else {
//                    self.gameManager.stateMachine.enter(GameManager.TrackThrowsState.self)
//                }
//            }
        default:
            break
        }
    }
}
