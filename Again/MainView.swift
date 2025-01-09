//
//  MainView.swift
//  PlaygroundExploration
//
//  Created by Alpay Calalli on 16.12.24.
//

import PhotosUI
import AVFoundation
import Vision
import SwiftUI

struct MainView: View {
    @State var roi: CGRect = CGRect(x: 0, y: 0.4, width: 1, height: 0.5)
    @State var duration: Double = 0.0
    @State var points: [VNPoint] = []
    
    @State private var recordedVideoSource: AVAsset?
    @State private var pixelBuffer: CMSampleBuffer?
    @State private var orientation: CGImagePropertyOrientation?
    @State private var frameRect: CGRect = CGRect(x: 0, y: 0.4, width: 1, height: 0.5)
    
    @State private var boardRect: CGPath?
    
    @State private var showFileImporter = false
    @State private var photo: PhotosPickerItem?
    
    @State private var detectTrajectoryRequest: VNDetectTrajectoriesRequest! = VNDetectTrajectoriesRequest(frameAnalysisSpacing: .zero, trajectoryLength: GameConstants.trajectoryLength)
    
    @State private var observations: [VNTrajectoryObservation] = []
    
    @State private var trajectoryDictionary: [String: [VNPoint]] = [:]
    
    @State private var isLiveCameraSelected = false
    
    @State private var lastShotMetrics: ShotMetrics? = nil
    
    @State private var showShotResultLabel = false
    
    var lastShotMetricsBinding: Binding<ShotMetrics?> {
        .init {
            lastShotMetrics
        } set: { newValue in
            print("bura lastshotmetrics", "salam")
            lastShotMetrics = newValue
            showShotResultLabel = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showShotResultLabel = false
            }
        }
    }

    
    var body: some View {
        ZStack {
            if let recordedVideoSource {
//                if let boardRect {
//                    Path(boardRect)
//                        .stroke(.primary, lineWidth: 2)
//                        .zIndex(100)
//                        .onChange(of: boardRect) { old, new in
//                            print("boardrect", new)
//                        }
////                    Path(roundedRect: boardRect, cornerRadius: 5)
//                }
                
                ContentAnalysisView(recordedVideoSource: recordedVideoSource, lastShotMetrics: lastShotMetricsBinding)
                    .zIndex(99)
                    .overlay(alignment: .bottomTrailing) {
                        if let lastShotMetrics {
                            VStack {
                                Text(lastShotMetrics.releaseAngle.formatted())
                                    .font(.largeTitle)
                                    .zIndex(999)
                                    .foregroundStyle(.white)
                                
                                Text("Ball Speed: " + lastShotMetrics.speed.formatted() + " MPH")
                                    .font(.largeTitle)
                                    .zIndex(999)
                                    .foregroundStyle(.white)
                            }
                            .padding()
                        }
                    }
                    .overlay {
                        if let lastShotMetrics, showShotResultLabel {
                            Text(lastShotMetrics.isScore ? "✅Score" : "❌Miss")
                                .font(.largeTitle)
                                .zIndex(999)
//                                .animation(.easeInOut, value: showShotResultLabel)
                                .transition(.scale)
                        }
                    }
                
//                CameraView(recordedVideoAsset: recordedVideoSource)
//                    .onTapGesture {
//                        showFileImporter = true
//                    }
            } else if isLiveCameraSelected {
                ContentAnalysisView(recordedVideoSource: nil, lastShotMetrics: lastShotMetricsBinding)
            } else {
                VStack {
                    Button("Import video") { showFileImporter = true }
                        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.movie], onCompletion: { result in
                            switch result {
                            case .success(let success):
                                print(success.absoluteURL)
                                let selectedFileURL = success.absoluteURL
                                if selectedFileURL.startAccessingSecurityScopedResource() {
                                    let fileManager = FileManager.default
                                    if fileManager.fileExists(atPath: selectedFileURL.path) {
                                        print("FILE AVAILABLE")
                                    } else {
                                        print("FILE NOT AVAILABLE")
                                    }
                                    
                                    var error: NSError?
                                    
                                    NSFileCoordinator().coordinate(
                                        readingItemAt: selectedFileURL, options: .forUploading, error: &error) { url in
                                            print("coordinated URL", url)
                                            let coordinatedURL = url
                                            
                                            //                                        isShowingFileDetails = false
                                            //                                        importedFileURL = selectedFileURL
                                            
                                            do {
                                                let resources = try selectedFileURL.resourceValues(forKeys:[.fileSizeKey])
                                                let fileSize = resources.fileSize!
                                                print ("File Size is \(fileSize)")
                                            } catch {
                                                print("Error: \(error)")
                                            }
                                        }
                                }
                                Task {
                                    await MainActor.run {
                                        recordedVideoSource = AVURLAsset(url: success.absoluteURL)
                                    }
                                }
                            case .failure(let failure):
                                print("failure", failure.localizedDescription)
                            }
                        })
                    //                    .photosPicker(isPresented: $showFileImporter, selection: $photo, matching: .videos)
                        .onChange(of: photo) { oldValue, newValue in
                            newValue?.getURL(completionHandler: { result in
                                switch result {
                                case .success(let success):
                                    print(success.absoluteURL)
                                    Task {
                                        await MainActor.run {
                                            recordedVideoSource = AVURLAsset(url: success.absoluteURL)
                                        }
                                    }
                                case .failure(let failure):
                                    print("failure", failure.localizedDescription)
                                }
                            })
                        }
                    
                    Button("Live Camera") {
                        isLiveCameraSelected = true
                    }
                }
            }// file:///private/var/mobile/Containers/Shared/AppGroup/8E90476D-E920-48BC-A323-B5B2BB3B9CCB/File%20Provider%20Storage/slowed2.mov
            // file:///var/mobile/Containers/Data/Application/8F2C40F3-8E58-47E0-ABFB-DC98E212A3C1/Documents/CA9B33A0-E68A-4396-8073-A6FCE76F2BE2.mov


        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .overlay(alignment: .topLeading) {
            if recordedVideoSource != nil || isLiveCameraSelected {
                Button("Close", systemImage: "xmark") {
                    recordedVideoSource = nil
                    isLiveCameraSelected = false
                }
                .padding()
                .labelStyle(.iconOnly)
                .font(.largeTitle)
                .background(.gray, in: .circle)
            }
        }
        
//        ZStack {
//            if recordedVideoSource != nil {
//                GeometryReader { geo in
//                    VideoCameraView(recordedVideoSource: recordedVideoSource, imagePixelBuffer: $pixelBuffer, orientation: $orientation, frameRect: $frameRect)
//                        .zIndex(99)
//                        .onChange(of: pixelBuffer) { oldValue, newValue in
//                            if let newValue {
//                                let visionHandler = VNImageRequestHandler(cmSampleBuffer: newValue, orientation: .left, options: [:])
//                                
////                                detectTrajectoryRequest.regionOfInterest = frameRect
//                                
//                                if let results = self.detectTrajectoryRequest.results {
//                                    processTrajectoryObservation(results: results)
//                                }
//                                
//                                do {
//                                    try visionHandler.perform([self.detectTrajectoryRequest])
//                                    if let results = self.detectTrajectoryRequest.results {
////                                        results.forEach { obs in
////                                            obs.detectedPoints.forEach({ print($0.location) })
////                                            print("---")
////                                        }
////                                        observations = results
////                                        processTrajectoryObservations(results)
//                                    }
//                                } catch {
//                                    print("error", error.localizedDescription)
//                                }
//                            }
//                            
//                        }
//                        .overlay {
////                            Path { path in
////                                path.addLines(points.map { $0.location })
////                            }
////                            .applying(.init(scaleX: geo.size.width, y: geo.size.height))
////                            .stroke(.red, lineWidth: 2)
////                            .zIndex(9999)
//                            
////                            TrajectoryViewRepresentable(roi: $roi, duration: $duration, points: $points) { location, speed in
////                                print("Throw completed at \(location) with speed \(speed)")
////                            }
////                            .zIndex(999)
////                            .frame(maxWidth: .infinity, maxHeight: .infinity)
//
//                        }
//                }
//                
//                OnlyTrajGameView(observations: $observations, frameRect: $frameRect, points: $points)
//                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
//                
//            } else {
//                Button("Import video") { showFileImporter = true }
//                    .photosPicker(isPresented: $showFileImporter, selection: $photo, matching: .videos)
//                    .onChange(of: photo) { oldValue, newValue in
//                        newValue?.getURL(completionHandler: { result in
//                            switch result {
//                            case .success(let success):
//                                Task {
//                                    await MainActor.run {
//                                        recordedVideoSource = AVURLAsset(url: success.absoluteURL)
//                                    }
//                                }
//                            case .failure(let failure):
//                                print("failure", failure.localizedDescription)
//                            }
//                        })
//                    }
//            }
//            
//            
////            GameView()
////            
////            TrajectoryViewRepresentable(roi: $roi, duration: $duration, points: $points) { location, speed in
////                print("Throw completed at \(location) with speed \(speed)")
////            }
////            .frame(maxWidth: .infinity, maxHeight: .infinity)
//        }
    }
}

extension PhotosPickerItem {
    func getURL(completionHandler: @escaping @Sendable (_ result: Result<URL, Error>) -> Void) {
        // Step 1: Load as Data object.
        self.loadTransferable(type: Data.self) { result in
            switch result {
            case .success(let data):
                if let contentType = self.supportedContentTypes.first {
                    // Step 2: make the URL file name and a get a file extention.
                    let url = getDocumentsDirectory().appendingPathComponent("\(UUID().uuidString).\(contentType.preferredFilenameExtension ?? "")")
                    if let data = data {
                        do {
                            // Step 3: write to temp App file directory and return in completionHandler
                            try data.write(to: url)
                            completionHandler(.success(url))
                        } catch {
                            completionHandler(.failure(error))
                        }
                    }
                }
            case .failure(let failure):
                completionHandler(.failure(failure))
            }
        }
    }
}

func getDocumentsDirectory() -> URL {
    // find all possible documents directories for this user
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)

    // just send back the first one, which ought to be the only one
    return paths[0]
}

extension MainView {
    func processTrajectoryObservation(results: [VNTrajectoryObservation]) {
        
        // Clear and reset the trajectory view if there are no trajectories.
        guard !results.isEmpty else {
//            trajectoryView.resetPath()
            return
        }
//        print("Total trajectory count: \(results.count)")
        
        for trajectory in results {
            // Filter the trajectory.
            if filterParabola(trajectory: trajectory) {
                // Verify and correct an incomplete path.
                points = correctTrajectoryPath(trajectoryToCorrect: trajectory)
                
                // Display a transition.
//                trajectoryView.performTransition(.fadeIn, duration: 0.05)
                
                // Determine the size of the moving object that the app tracks.
                print("The object's moving average radius: \(trajectory.movingAverageRadius)")
            }
        }
    
    }
    
     func filterParabola(trajectory: VNTrajectoryObservation) -> Bool {
        
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
            - The trajectory confidence is greater than 0.9.
         
         Add additional filters based on trajectory speed, location, and properties.
         */
        if trajectoryDictionary[trajectory.uuid.uuidString]!.first!.x < trajectoryDictionary[trajectory.uuid.uuidString]!.last!.x
            && trajectoryDictionary[trajectory.uuid.uuidString]!.first!.x < 0.5
            && trajectoryDictionary[trajectory.uuid.uuidString]!.count >= 8
            && trajectory.equationCoefficients[0] <= 0
            && trajectory.confidence > 0.9 {
            return true
        } else {
            return false
        }
        
    }
    
    private func correctTrajectoryPath(trajectoryToCorrect: VNTrajectoryObservation) -> [VNPoint] {
    
        guard var basePoints = trajectoryDictionary[trajectoryToCorrect.uuid.uuidString],
              var basePointX = basePoints.first?.x else {
            return []
        }
        
        /**
         This is inside region-of-interest space where both x and y range between 0.0 and 1.0.
         If a left-to-right moving trajectory begins too far from a fixed region, extrapolate it back
         to that region using the available quadratic equation coefficients.
         */
        if basePointX > 0.1 {
            
            // Compute the initial trajectory location points based on the average
            // change in the x direction of the first five points.
            var sum = 0.0
            for i in 0..<5 {
                sum = sum + basePoints[i + 1].x - basePoints[i].x
            }
            let averageDifferenceInX = sum / 5.0
        
            while basePointX > 0.1 {
                let nextXValue = basePointX - averageDifferenceInX
                let aXX = Double(trajectoryToCorrect.equationCoefficients[0]) * nextXValue * nextXValue
                let bX = Double(trajectoryToCorrect.equationCoefficients[1]) * nextXValue
                let c = Double(trajectoryToCorrect.equationCoefficients[2])
                
                let nextYValue = aXX + bX + c
                if nextYValue > 0 {
                    // Insert values into the trajectory path present in the positive Cartesian space.
                    basePoints.insert(VNPoint(x: nextXValue, y: nextYValue), at: 0)
                }
                basePointX = nextXValue
            }
            // Update the dictionary with the corrected path.
            trajectoryDictionary[trajectoryToCorrect.uuid.uuidString] = basePoints
            
        }
        return basePoints
        
    }
    
    func processTrajectoryObservations(_ results: [VNTrajectoryObservation]) {
//        if self.trajectoryView.inFlight && results.count < 1 {
//            // The trajectory is already in flight but VNDetectTrajectoriesRequest doesn't return any trajectory observations.
//            self.noObservationFrameCount += 1
//            if self.noObservationFrameCount > GameConstants.noObservationFrameLimit {
//                // Ending the throw as we don't see any observations in consecutive GameConstants.noObservationFrameLimit frames.
//                self.updatePlayerStats(controller)
//            }
//        } else {
        for path in results where path.confidence > 0.90 {
                // VNDetectTrajectoriesRequest has returned some trajectory observations.
                // Process the path only when the confidence is over 90%.
                duration = path.timeRange.duration.seconds
                points = path.detectedPoints
            
//            let playerRegion: CGRect = .init(x: 1, y: 0, width: 100, height: 100)
//            let throwWindowXBuffer: CGFloat = 50
//            let throwWindowYBuffer: CGFloat = 50
//            let targetWindowXBuffer: CGFloat = 50
//            let throwRegionWidth: CGFloat = 400
//            roi = CGRect(x: playerRegion.maxX + throwWindowXBuffer, y: 0, width: throwRegionWidth, height: playerRegion.maxY - throwWindowYBuffer)

//                self.trajectoryView.perform(transition: .fadeIn, duration: 0.25)
//                if !self.trajectoryView.fullTrajectory.isEmpty {
//                    // Hide the previous throw metrics once a new throw is detected.
//                    if !self.dashboardView.isHidden {
//                        self.resetKPILabels()
//                    }
//                    self.updateTrajectoryRegions()
//                    if self.trajectoryView.isThrowComplete {
//                        // Update the player statistics once the throw is complete.
//                        self.updatePlayerStats(controller)
//                    }
//                }
//                self.noObservationFrameCount = 0
            }
//        }
    }
}
