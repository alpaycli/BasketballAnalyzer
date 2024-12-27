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
//            guard vc?.boardDetected == false else { return }
            do {
                try vc?.detectBoard(controller, buffer, orientation)
            } catch {
                print("couldn't detect board:", error.localizedDescription)
            }
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
    private var cameraViewController = CameraViewController()
    private var trajectoryView = TrajectoryView()
    private let boardBoundingBox = BoundingBoxView()
    
    private var boardRegion: CGRect = .zero
    
    var boardDetected = false
    
    private var setupComplete = false
    private var detectTrajectoryRequest: VNDetectTrajectoriesRequest!
    
    private var hoopDetectionRequest: VNCoreMLRequest!
    
    // A dictionary that stores all trajectories.
    private var trajectoryDictionary: [String: [VNPoint]] = [:]
    
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
    
    private func configureView() {
        
        // Set up the video layers.
//        cameraViewController = CameraViewController()
        cameraViewController.view.frame = view.bounds
        addChild(cameraViewController)
        cameraViewController.beginAppearanceTransition(true, animated: true)
        view.addSubview(cameraViewController.view)
        cameraViewController.endAppearanceTransition()
        cameraViewController.didMove(toParent: self)
        
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
        
        // Add a custom trajectory view for overlaying trajectories.
        view.addSubview(trajectoryView)
                
        // TODO: add close button
    }
    
}

// MARK: - CameraViewController delegate action

extension ContentAnalysisViewController {
    func cameraVCDelegateAction(_ controller: CameraViewController, didReceiveBuffer buffer: CMSampleBuffer, orientation: CGImagePropertyOrientation) {
        // video camera actions
        let visionHandler = VNImageRequestHandler(cmSampleBuffer: buffer,
                                                  orientation: orientation,
                                                  options: [:])
        
        let normalizedFrame = CGRect(x: 0, y: 0.4, width: 1, height: 0.5)
        DispatchQueue.main.async {
            // Get the frame of the rendered view.
            print("trajectory frame set", controller.viewRectForVisionRect(normalizedFrame))
            self.trajectoryView.frame = controller.viewRectForVisionRect(normalizedFrame)
        }
        
        self.setUpDetectTrajectoriesRequestWithMaxDimension()
        
        guard let detectTrajectoryRequest else {
            print("Failed to retrieve a trajectory request.")
            return
        }
        
        do {
            // Following optional bounds by checking for the moving average radius
            // of the trajectories the app is looking for.
            //            detectTrajectoryRequest.objectMinimumNormalizedRadius = 10.0 / Float(1920.0)
            //            detectTrajectoryRequest.objectMaximumNormalizedRadius = 30.0 / Float(1920.0)
            
            // Help manage the real-time use case to improve the precision versus delay tradeoff.
            //            detectTrajectoryRequest.targetFrameTime = CMTimeMake(value: 1, timescale: 60)
            
            // The region of interest where the object is moving in the normalized image space.
            detectTrajectoryRequest.regionOfInterest = normalizedFrame
            //
            try visionHandler.perform([detectTrajectoryRequest])
        } catch {
            print("Failed to perform the trajectory request: \(error.localizedDescription)")
            return
        }
        
    }
}

// MARK: - Detect hoop stuff

extension ContentAnalysisViewController {
    /* func analyzeBoardContours(_ contours: [VNContour]) -> (edgePath: CGPath, holePath: CGPath)? {
        // Simplify contours and ignore resulting contours with less than 3 points.
        let polyContours = contours.compactMap { (contour) -> VNContour? in
            guard let polyContour = try? contour.polygonApproximation(epsilon: 0.01),
                  polyContour.pointCount >= 3 else {
                return nil
            }
            return polyContour
        }
        // Board contour is the contour with the largest amount of points.
        guard let boardContour = polyContours.max(by: { $0.pointCount < $1.pointCount }) else {
            return nil
        }
        // First, find the board edge which is the longest diagonal segment of the contour
        // located in the top part of the board's bounding box.
        let contourPoints = boardContour.normalizedPoints.map { return CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
        let diagonalThreshold = CGFloat(0.02)
        var largestDiff = CGFloat(0.0)
        let boardPath = UIBezierPath()
        let countLessOne = contourPoints.count - 1
        // Both points should be in the top 2/3rds of the board's bounding box.
        // Additionally one of them should be in the left half
        // and the other on in the right half of the board's bounding box.
        for (point1, point2) in zip(contourPoints.prefix(countLessOne), contourPoints.suffix(countLessOne)) where
            min(point1.x, point2.x) < 0.5 && max(point1.x, point2.x) > 0.5 && point1.y >= 0.3 && point2.y >= 0.3 {
            let diffX = abs(point1.x - point2.x)
            let diffY = abs(point1.y - point2.y)
            guard diffX > diagonalThreshold && diffY > diagonalThreshold else {
                // This is not a diagonal line, skip this segment.
                continue
            }
            if diffX + diffY > largestDiff {
                largestDiff = diffX + diffY
                boardPath.removeAllPoints()
                boardPath.move(to: point1)
                boardPath.addLine(to: point2)
            }
        }
        guard largestDiff > 0 else {
            return nil
        }
        // Finally, find the hole contorur which should be located in the top right quadrant
        // of the board's bounding box.
        var holePath: CGPath?
        for contour in polyContours where contour != boardContour {
            let normalizedPath = contour.normalizedPath
            let normalizedBox = normalizedPath.boundingBox
            if normalizedBox.minX >= 0.5 && normalizedBox.minY >= 0.5 {
                holePath = normalizedPath
                break
            }
        }
        // Return nil if we failed to find the hole.
        guard let detectedHolePath = holePath else {
            return nil
        }
        
        return (boardPath.cgPath, detectedHolePath)
    } */
    
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
                boardRegion = boardBoundingBox.frame
//                print(gameManager.boardRegion)
                // Calculate board length based on the bounding box of the edge.
                let edgeNormalizedBB = boardPath.boundingBox
                // Convert normalized bounding box size to points.
                let edgeSize = CGSize(width: edgeNormalizedBB.width * boardBoundingBox.frame.width,
                                      height: edgeNormalizedBB.height * boardBoundingBox.frame.height)

                
                let highlightPath = UIBezierPath(cgPath: boardPath)
                boardBoundingBox.visionPath = highlightPath.cgPath
                boardBoundingBox.borderColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 0.199807363)
                
                boardDetected = true
//                self.gameManager.stateMachine.enter(GameManager.DetectedBoardState.self)
            }
        }
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
        
        /**
         Filter the trajectory with the following conditions:
         - The trajectory moves from left to right.
         - The trajectory starts in the first half of the region of interest.
         - The trajectory length increases to 8.
         - The trajectory contains a parabolic equation constant a, less than or equal to 0, and implies there
         are either straight lines or downward-facing lines.
         
         Add additional filters based on trajectory speed, location, and properties.
         */
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
        
        print("**/basePointX", basePointX)
        /**
         This is inside region-of-interest space where both x and y range between 0.0 and 1.0.
         If a trajectory begins too far from a fixed region, extrapolate it back
         to that region using the available quadratic equation coefficients.
         */
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
        
        /**
         Define what the sample app looks for, and how to handle the output trajectories.
         Setting the frame time spacing to (10, 600) so the framework looks for trajectories after each 1/60 second of video.
         Setting the trajectory length to 6 so the framework returns trajectories of a length of 6 or greater.
         Use a shorter length for real-time apps, and use longer lengths to observe finer and longer curves.
         */
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
