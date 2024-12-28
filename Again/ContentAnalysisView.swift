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
            try? vc?.detectBoard(controller, buffer, orientation)
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
    
    private var throwRegion = CGRect.null
    private var targetRegion = CGRect.null
    
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
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        recordedVideoSource = nil
        detectTrajectoryRequest = nil
    }
    
    // MARK: - Public Methods
    
    func setCameraVCDelegate(_ cameraVCDelegate: CameraViewControllerOutputDelegate) {
        self.cameraViewController.outputDelegate = cameraVCDelegate
    }
    
    // MARK: - Private Methods
    
    // Adjust the throwRegion based on location of the bag.
    // Move the throwRegion to the right until we reach the target region.
    func updateTrajectoryRegions() {
        let trajectoryLocation = trajectoryView.fullTrajectory.currentPoint
        let didBagCrossCenterOfThrowRegion = trajectoryLocation.x > throwRegion.origin.x + throwRegion.width / 2
        guard !(throwRegion.contains(trajectoryLocation) && didBagCrossCenterOfThrowRegion) else {
            return
        }
        // Overlap buffer window between throwRegion and targetRegion
        let overlapWindowBuffer: CGFloat = 50
        if targetRegion.contains(trajectoryLocation) {
            // When bag is in target region, set the throwRegion to targetRegion.
            throwRegion = targetRegion
        } else if trajectoryLocation.x + throwRegion.width / 2 - overlapWindowBuffer < targetRegion.origin.x {
            // Move the throwRegion forward to have the bag at the center.
            throwRegion.origin.x = trajectoryLocation.x - throwRegion.width / 2
        }
        trajectoryView.roi = throwRegion
    }
    
    func processTrajectoryObservations(_ controller: CameraViewController, _ results: [VNTrajectoryObservation]) {
        if self.trajectoryView.inFlight && results.count < 1 {
            // The trajectory is already in flight but VNDetectTrajectoriesRequest doesn't return any trajectory observations.
            self.noObservationFrameCount += 1
            if self.noObservationFrameCount > GameConstants.noObservationFrameLimit {
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
                    // Hide the previous throw metrics once a new throw is detected.
//                    if !self.dashboardView.isHidden {
//                        self.resetKPILabels()
//                    }
                    self.updateTrajectoryRegions()
                    if self.trajectoryView.isThrowComplete {
                        // Update the player statistics once the throw is complete.
//                        self.updatePlayerStats(controller)
                        trajectoryView.resetPath()
                    }
                }
                self.noObservationFrameCount = 0
            }
        }
    }
    
    func updateBoundingBox(_ boundingBox: BoundingBoxView, withRect rect: CGRect?) {
        // Update the frame for player bounding box
        boundingBox.frame = rect ?? .zero
        boundingBox.performTransition((rect == nil ? .fadeOut : .fadeIn), duration: 0.1)
    }
    
    func updateBoundingBox(_ boundingBox: BoundingBoxView, withViewRect rect: CGRect?, visionRect: CGRect) {
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
            print("*joints", joints)
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
    
    // Define regions to filter relavant trajectories for the game
    // throwRegion: Region to the right of the player to detect start of throw
    // targetRegion: Region around the board to determine end of throw
    private func resetTrajectoryRegions() {
        DispatchQueue.main.async {
            let boardRegion = self.gameManager.boardRegion
            let playerRegion = self.playerBoundingBox.frame
            print("*boardregion", boardRegion)
            print("*playerregion", playerRegion)
            let throwWindowXBuffer: CGFloat = 50
            let throwWindowYBuffer: CGFloat = 50
            let targetWindowXBuffer: CGFloat = 50
            let throwRegionWidth: CGFloat = 400
            self.throwRegion = CGRect(x: playerRegion.maxX + throwWindowXBuffer, y: 0, width: throwRegionWidth, height: playerRegion.maxY - throwWindowYBuffer)
            self.targetRegion = CGRect(x: boardRegion.minX - targetWindowXBuffer, y: 0,
                                  width: boardRegion.width + 2 * targetWindowXBuffer, height: boardRegion.maxY)
        }
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
    
}

// MARK: - CameraViewController delegate action

extension ContentAnalysisViewController {
    func cameraVCDelegateAction(_ controller: CameraViewController, didReceiveBuffer buffer: CMSampleBuffer, orientation: CGImagePropertyOrientation) {
        // video camera actions
        let visionHandler = VNImageRequestHandler(cmSampleBuffer: buffer, orientation: orientation, options: [:])
        if gameManager.stateMachine.currentState is GameManager.TrackThrowsState {
            DispatchQueue.main.async {
                // Get the frame of rendered view
                let normalizedFrame = CGRect(x: 0, y: 0, width: 1, height: 1)
                self.jointSegmentView.frame = controller.viewRectForVisionRect(normalizedFrame)
                self.trajectoryView.frame = controller.viewRectForVisionRect(normalizedFrame)
            }
            // Perform the trajectory request in a separate dispatch queue.
//            trajectoryQueue.async {
                do {
                    try visionHandler.perform([self.detectTrajectoryRequest])
                    if let results = self.detectTrajectoryRequest.results {
                        print("*trajectoryresults", results)
                        DispatchQueue.main.async   {
                            self.processTrajectoryObservations(controller, results)
                        }
                    }
                } catch {
                    print("error", error.localizedDescription)
                }
//            }
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
                            self.resetTrajectoryRegions()
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
    fileprivate func detectBoard(_ controller: CameraViewController, _ buffer: CMSampleBuffer, _ orientation: CGImagePropertyOrientation) throws {
        // This is where we detect the board.
        let visionHandler = VNImageRequestHandler(cmSampleBuffer: buffer, orientation: orientation, options: [:])
        try visionHandler.perform([hoopDetectionRequest])
        var rect: CGRect?
        var visionRect = CGRect.null
        if let results = hoopDetectionRequest.results as? [VNDetectedObjectObservation] {
            // Filter out classification results with low confidence
            print("*****boardresults/", results.map { $0.confidence })
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

extension ContentAnalysisViewController: GameStateChangeObserver {
    func gameManagerDidEnter(state: GameManager.State, from previousState: GameManager.State?) {
        print("gamemanager.state", state)
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
            resetTrajectoryRegions()
            trajectoryView.roi = throwRegion
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


// MARK: - Trajectory stuff

/*
extension ContentAnalysisViewController {
    private func processTrajectoryObservation(results: [VNTrajectoryObservation]) {
        
        // Clear and reset the trajectory view if there are no trajectories.``
        guard !results.isEmpty else {
            print("result is empty")
            trajectoryView.resetPath()
            return
        }
        print("Total trajectory count: \(results.count)")
        
        for trajectory in results where trajectory.confidence > 0.9 {
            // Filter the trajectory.
            if filterParabola(trajectory: trajectory) {
                // Verify and correct an incomplete path.
                trajectoryView.points = correctTrajectoryPath(trajectoryToCorrect: trajectory)
                
                // Display a transition.
                trajectoryView.performTransition(.fadeIn, duration: 0.05)
                
                // Determine the size of the moving object that the app tracks.
                print("The object's moving average radius: \(trajectory.movingAverageRadius)")
            }
        }
    
    }
    
    private func filterParabola(trajectory: VNTrajectoryObservation) -> Bool {
        
        if trajectoryDictionary[trajectory.uuid.uuidString] == nil {
            // Add the new trajectories to the dictionary.
            trajectoryDictionary[trajectory.uuid.uuidString] = trajectory.projectedPoints
        } else {
            // Increase the points on the existing trajectory.
            // The framework returns the last five projected points, so check whether a trajectory is
            // increasing, and update it.
            if trajectoryDictionary[trajectory.uuid.uuidString]!.last != trajectory.projectedPoints[4] {
                trajectoryDictionary[trajectory.uuid.uuidString]!.append(trajectory.projectedPoints[4])
            }
        }
        
        
//         Filter the trajectory with the following conditions:
//         - The trajectory moves from left to right.
//         - The trajectory starts in the first half of the region of interest.
//         - The trajectory length increases to 8.
//         - The trajectory contains a parabolic equation constant a, less than or equal to 0, and implies there
//         are either straight lines or downward-facing lines.
         
//         Add additional filters based on trajectory speed, location, and properties.
        if trajectoryDictionary[trajectory.uuid.uuidString]!.first!.x < trajectoryDictionary[trajectory.uuid.uuidString]!.last!.x,
            trajectoryDictionary[trajectory.uuid.uuidString]!.first!.x < 0.5,
            trajectoryDictionary[trajectory.uuid.uuidString]!.count >= 8,
            trajectory.equationCoefficients[0] <= 0
        {
            print("***true")
            return true
        } else {
            print("***False")
            return false
        }
        
    }
    
    private func correctTrajectoryPath(trajectoryToCorrect: VNTrajectoryObservation) -> [VNPoint] {
        
        guard var basePoints = trajectoryDictionary[trajectoryToCorrect.uuid.uuidString],
              let basePointX = basePoints.first?.x else {
            return []
        }
        
        print("*basePointX", basePointX)
        
//         This is inside region-of-interest space where both x and y range between 0.0 and 1.0.
//         If a trajectory begins too far from a fixed region, extrapolate it back
//         to that region using the available quadratic equation coefficients.
         if basePointX < 0.9, basePointX > 0.5 { // Right-to-left correction
            
            // Compute the initial trajectory location points based on the average
            // change in the x direction of the first five points.
            var sum = 0.0
            for i in 0..<5 {
                sum += abs(basePoints[i + 1].x - basePoints[i].x)
                print("**difference/", basePoints[i + 1].x - basePoints[i].x)
                print("**sum menfi ola bilmez/", sum)
            }
            let averageDifferenceInX = sum / 5.0
            print("**averageDifferenceInX/", averageDifferenceInX)
            
            var currentX = basePointX
            while currentX < 0.9, currentX > 0.1 {
                let nextXValue = currentX - averageDifferenceInX
                let aXX = Double(trajectoryToCorrect.equationCoefficients[0]) * nextXValue * nextXValue
                let bX = Double(trajectoryToCorrect.equationCoefficients[1]) * nextXValue
                let c = Double(trajectoryToCorrect.equationCoefficients[2])
                
                let nextYValue = aXX + bX + c
                if nextYValue > 0 {
                    
                    basePoints.append(VNPoint(x: nextXValue, y: nextYValue))
//                    print("**nextXValue/", nextXValue)
//                    print("**nextYValue/", nextYValue)
                }
                
                currentX = nextXValue
            }
        } else if basePointX > 0.1 { // Left-to-right correction
            
            // Compute the initial trajectory location points based on the average
            // change in the x direction of the first five points.
            var sum = 0.0
            for i in 0..<5 {
                print("**difference/", basePoints[i + 1].x - basePoints[i].x)
                sum += abs(basePoints[i + 1].x - basePoints[i].x)
                print("**sum/", sum)
            }
            let averageDifferenceInX = sum / 5.0
            print("**averageDifferenceInX/", averageDifferenceInX)
            
            var currentX = basePointX
            while currentX > 0.1 {
                let nextXValue = currentX - averageDifferenceInX
                let aXX = Double(trajectoryToCorrect.equationCoefficients[0]) * nextXValue * nextXValue
                let bX = Double(trajectoryToCorrect.equationCoefficients[1]) * nextXValue
                let c = Double(trajectoryToCorrect.equationCoefficients[2])
                
                let nextYValue = aXX + bX + c
                if nextYValue > 0 {
                    
                    basePoints.insert(VNPoint(x: nextXValue, y: nextYValue), at: 0)
//                    print("**nextXValue/", nextXValue)
//                    print("**nextYValue/", nextYValue)
                }
                
                currentX = nextXValue
            }
        }
        
        // Update the dictionary with the corrected path.
        trajectoryDictionary[trajectoryToCorrect.uuid.uuidString] = basePoints
        
        return basePoints
    }
    
    // The sample app calls this when the camera view delegate begins reading
    // frames of a video buffer.
    private func setUpDetectTrajectoriesRequestWithMaxDimension() {
        
        guard setupComplete == false else {
            return
        }
        
        
//         Define what the sample app looks for, and how to handle the output trajectories.
//         Setting the frame time spacing to (10, 600) so the framework looks for trajectories after each 1/60 second of video.
//         Setting the trajectory length to 6 so the framework returns trajectories of a length of 6 or greater.
//         Use a shorter length for real-time apps, and use longer lengths to observe finer and longer curves.
         
        detectTrajectoryRequest = VNDetectTrajectoriesRequest(frameAnalysisSpacing: CMTime(value: 10, timescale: 600),
                                                              trajectoryLength: 3) { [weak self] (request: VNRequest, error: Error?) -> Void in
            
            if let error {
                print("error", error.localizedDescription)
            }
            guard let results = request.results as? [VNTrajectoryObservation] else {
                return
            }
            
            DispatchQueue.main.async {
                self?.processTrajectoryObservation(results: results)
            }
            
        }
        setupComplete = true
        
    }
}
*/

func getBodyJointsFor(observation: VNHumanBodyPoseObservation) -> ([VNHumanBodyPoseObservation.JointName: CGPoint]) {
    var joints = [VNHumanBodyPoseObservation.JointName: CGPoint]()
    guard let identifiedPoints = try? observation.recognizedPoints(.all) else {
        return joints
    }
    for (key, point) in identifiedPoints {
        guard point.confidence > 0.1 else { continue }
        if jointsOfInterest.contains(key) {
            joints[key] = point.location
        }
    }
    return joints
}
