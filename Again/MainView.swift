//
//  MainView.swift
//  PlaygroundExploration
//
//  Created by Alpay Calalli on 16.12.24.
//

import Observation
import PhotosUI
import AVFoundation
import Vision
import SwiftUI

@Observable
class ContentViewModel {
    var manualHoopSelectorState: AreaSelectorState = .none {
        didSet {
            print("manualHoopSelectorState", manualHoopSelectorState)
        }
    }
    var lastShotMetrics: ShotMetrics? = nil
    var playerStats: PlayerStats? = nil
    var setupGuideLabel: String? = nil
    var setupStateModel = SetupStateModel()
    var isFinishButtonPressed = false
    var isRecordingPermissionDenied = false
    
    var hoopDetectionRequest: VNCoreMLRequest
    
    func reset() {
        manualHoopSelectorState = .none
        lastShotMetrics = nil
        playerStats = nil
        setupGuideLabel = nil
        setupStateModel = .init()
        isFinishButtonPressed = false
        isRecordingPermissionDenied = false
    }
    
    init() {
        // Create Vision request based on CoreML model
        let model = try! VNCoreMLModel(for: HoopDetectorBeta13x13(configuration: MLModelConfiguration()).model)
        hoopDetectionRequest = VNCoreMLRequest(model: model)
        
    }
    
    var isHoopPlaced: Bool {
        setupStateModel.hoopDetected
    }
}

struct ContentView: View {
    
    // MARK: - ViewModel
    
    @State private var viewModel = ContentViewModel()
    
    // MARK: -
    
    @State private var shotPaths: [CGPath] = []
    
    @State private var isTestMode = false
    @State private var recordedVideoSource: AVAsset?
    @State private var isLiveCameraSelected = false
    
    @State private var showFileImporter = false
    @State private var photo: PhotosPickerItem?
        
    var showSetupStateLabels: Bool {
        guard viewModel.manualHoopSelectorState == .none else { return false }
        
        return !viewModel.setupStateModel.isAllDone
    }
    
    @State private var isVideoEnded = false
    
    var showMetricsAndScore: Bool {
        !isVideoEnded && !viewModel.isFinishButtonPressed
    }
    
    var pub = NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
    
    @Namespace private var namespace
    
    // MARK: - Summary

    // bu deyqe lazimsizdi
    @State private var showShotResultLabel = false
    
    var body: some View {
        NavigationStack {
            Group {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    padContent
                } else if UIDevice.current.userInterfaceIdiom == .phone {
                    phoneContent
                    #warning("delete later")
                }
            }
            .navigationDestination(isPresented: $isTestMode) {
                contentViewWithRecordedVideo(isTestMode: isTestMode)
                    .navigationTransition(.zoom(sourceID: "recordedVidedZoom", in: namespace))
            }
            .navigationDestination(item: $recordedVideoSource) { item in
                contentViewWithRecordedVideo(item)
                    .navigationTransition(.zoom(sourceID: "recordedVidedZoom", in: namespace))
            }
            .navigationDestination(isPresented: $isLiveCameraSelected) {
                contentViewWithLiveCamera
                    .navigationTransition(.zoom(sourceID: "liveCameraZoom", in: namespace))
            }
            .onReceive(pub) { c in
                print("video ended in view", c.name.rawValue, c.name)
                isVideoEnded = true
                //                shotPaths = viewModel.playerStats?.shotPaths ?? []
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.movie], onCompletion: { result in
                switch result {
                case let .success(url):
                    handleImportedVideoFileURL(url)
                case let .failure(error):
                    print("failure", error.localizedDescription)
                }
            })
            .buttonStyle(.plain)
            //            .photosPicker(isPresented: $showFileImporter, selection: $photo, matching: .videos)
            //            .onChange(of: photo) { oldValue, newValue in
            //                if let newValue {
            //                    handlePhotoPickerSelection(newValue)
            //                }
            //            }
        }
    }
}

// MARK: - Content

extension ContentView {
    private var padContent: some View {
        VStack {
            HStack {
                Spacer()
                NavigationLink {
                    InstructionsView()
                } label : {
                    Text("Show Guides")   
                }
                .font(.largeTitle)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.red)
                .foregroundStyle(.white)
                .fontWeight(.bold)
                .padding()
            }
            Spacer()
            
            VStack {
                Image(systemName: "square.and.arrow.up")
                Button("Upload video") { showFileImporter = true }
            }
            .frame(width: 280, height: 220)
            .background(.gray, in: .rect(cornerRadius: 15))
            .foregroundStyle(.white)
            .fontWeight(.bold)
            .font(.largeTitle)
            
            VStack {
                Image(systemName: "video")
                Button("Live Camera") {
                    GameManager.shared.reset()
                    GameManager.shared.stateMachine.enter(GameManager.SetupCameraState.self)
                    
                    isLiveCameraSelected = true
                }
            }
            .frame(width: 280, height: 220)
            .background(.gray, in: .rect(cornerRadius: 15))
            .foregroundStyle(.white)
            .fontWeight(.bold)
            .font(.largeTitle)
            
            Button("Test with a sample video") {
                GameManager.shared.stateMachine.enter(GameManager.SetupCameraState.self)
                isTestMode = true
            }
            .font(.title.smallCaps())
            .fontDesign(.rounded)
            .fontWeight(.bold)
            .foregroundStyle(.blue)
            .padding(.top)
            
            Spacer()
        }
    }
    
    private var phoneContent: some View {
        VStack {
            HStack {
                Spacer()
                NavigationLink {
                    InstructionsView()
                } label: {
                    Text("Show Guides")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.red)
                .foregroundStyle(.white)
                .fontWeight(.bold)
                .padding()
            }
            Spacer()
            
            Button("Upload video", systemImage: "square.and.arrow.up") { showFileImporter = true }
                .foregroundStyle(.white)
                .fontWeight(.bold)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.gray)
            
            Button("Live Camera", systemImage: "video") {
                GameManager.shared.reset()
                GameManager.shared.stateMachine.enter(GameManager.SetupCameraState.self)
                
                isLiveCameraSelected = true
            }
            .foregroundStyle(.white)
            .fontWeight(.bold)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            
            Button("Test with a sample video") {
                GameManager.shared.stateMachine.enter(GameManager.SetupCameraState.self)
                isTestMode = true
            }
            .font(.title.smallCaps())
            .fontDesign(.rounded)
            .fontWeight(.bold)
            .foregroundStyle(.blue)
            .padding(.top)
            
            Spacer()
        }
    }
}

// MARK: - Methods

extension ContentView {
    private func handlePhotoPickerSelection(_ item: PhotosPickerItem) {
        item.getURL(completionHandler: { result in
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
    
    private func handleImportedVideoFileURL(_ url: URL) {
        let selectedFileURL = url.absoluteURL
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
                GameManager.shared.reset()
                GameManager.shared.stateMachine.enter(GameManager.SetupCameraState.self)
                
                recordedVideoSource = AVURLAsset(url: selectedFileURL)
            }
        }
    }
}

// MARK: - UI components

extension ContentView {
    private var closeButton: some View {
        Button("Close", systemImage: "xmark") {
            recordedVideoSource = nil
            isLiveCameraSelected = false
            isTestMode = false
            
            shotPaths = []
//            viewModel.reset()
            isVideoEnded = false
            
            GameManager.shared.stateMachine.enter(GameManager.InactiveState.self)
        }
        .padding()
        .labelStyle(.iconOnly)
        .font(.largeTitle)
        .background(.gray, in: .circle)
    }
    
    private var makeAndAttemptsView: some View {
        HStack {
            VStack {
                Text(viewModel.playerStats?.totalScore.formatted() ?? "0")
                    .font(.largeTitle)
                    .fontDesign(.monospaced)
                    .animation(.default, value: viewModel.playerStats?.totalScore)
                    .contentTransition(.numericText())
                Text("make")
                    .font(.headline.uppercaseSmallCaps())
//                            .foregroundStyle(.secondary)
            }
            Text("/")
                .font(.largeTitle)
                .padding(.horizontal)
            VStack {
                Text(viewModel.playerStats?.shotCount.formatted() ?? "0")
                    .font(.largeTitle)
                    .fontDesign(.monospaced)
                    .animation(.default, value: viewModel.playerStats?.totalScore)
                    .contentTransition(.numericText())
                Text("attempt")
                    .font(.headline.uppercaseSmallCaps())
//                            .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.white.gradient)
    }
    
    private var setupStatesView: some View {
        VStack(alignment: .leading) {
            Text("Hoop Detected: " + "\(viewModel.setupStateModel.hoopDetected ? "✅" : "❌")")
            Text("Hoop Contours Detected: " + "\(viewModel.setupStateModel.hoopContoursDetected ? "✅" : "❌")")
            Text("Player Detected: " + "\(viewModel.setupStateModel.playerDetected ? "✅" : "❌")")
        }
        .fontDesign(.monospaced)
        .foregroundStyle(.black)
        .padding()
        //                .frame(width: 200, height: 100)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 15))
    }
    
    private var shotPathsView: some View {
        ForEach(shotPaths, id: \.self) { shotPath in
            Path(shotPath)
                .stroke(.red, lineWidth: 3)
        }
    }
    
    private var manualHoopSelectionButtons: some View {
        HStack {
            if viewModel.manualHoopSelectorState == .inProgress {
                Button("Cancel") {
                    viewModel.manualHoopSelectorState = .none
                }
                .buttonStyle(.borderless)
                .tint(.green)
                .font(.headline.smallCaps())
                .padding()
            }
            Button(viewModel.manualHoopSelectorState == .inProgress ? "Set" : "Set Hoop Manually") {
                if viewModel.manualHoopSelectorState == .inProgress {
                    viewModel.manualHoopSelectorState = .set
                } else {
                    viewModel.manualHoopSelectorState = .inProgress
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .font(.headline.smallCaps())
            .padding()
        }
    }
    
    private var recordingDeniedLabel: some View {
        Label("Recording denied", systemImage: "stop.circle")
            .padding(5)
            .background(.thinMaterial, in: .rect(cornerRadius: 10))
            .foregroundStyle(.red)
            .font(.headline.smallCaps())
    }
}

// MARK: - Contents

extension ContentView {
    private func contentViewWithRecordedVideo(_ item: AVAsset? = nil, isTestMode: Bool = false) -> some View {
        ContentAnalysisView(recordedVideoSource: item, isTestMode: isTestMode, viewModel: viewModel)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                if let setupGuideLabel = viewModel.setupGuideLabel, showSetupStateLabels {
                    Text(setupGuideLabel)
                        .font(.largeTitle)
                        .padding()
                        .background(.thinMaterial, in: .rect(cornerRadius: 10))
                        .foregroundStyle(.black)
                }
            }
            .overlay(alignment: .top) {
                if viewModel.isRecordingPermissionDenied, showSetupStateLabels {
                    recordingDeniedLabel
                }
            }
            .overlay(alignment: .topLeading) {
                closeButton
            }
            .overlay(alignment: .topTrailing) {
                if !viewModel.isHoopPlaced || viewModel.manualHoopSelectorState == .inProgress {
                    manualHoopSelectionButtons
                }
            }
            .overlay(alignment: .bottom) {
                if showMetricsAndScore {
                    makeAndAttemptsView
                }
            }
            .overlay(alignment: .bottomLeading) {
                if let lastShotMetrics = viewModel.lastShotMetrics, showMetricsAndScore {
                    VStack(alignment: .leading) {
                        Text("Release Angel: ")
                            .foregroundStyle(.white)
                        +
                        Text(lastShotMetrics.releaseAngle.formatted())
                            .fontWeight(.bold)
                            .foregroundStyle(.orange)
                        
                        Text("Ball Speed: ")
                            .foregroundStyle(.white)
                        +
                        Text(lastShotMetrics.speed.formatted() + " MPH")
                            .fontWeight(.bold)
                            .foregroundStyle(.orange)
                        
                        if lastShotMetrics.shotResult != .score {
                            Text("Miss Reason: ")
                                .foregroundStyle(.white)
                            +
                            Text(lastShotMetrics.shotResult.description)
                                .fontWeight(.bold)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding()
                }
            }
            .overlay {
                if showSetupStateLabels {
                    setupStatesView
                }
            }
            .overlay {
                if !shotPaths.isEmpty {
                    shotPathsView
                }
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
    }
    
    private var contentViewWithLiveCamera: some View {
        ContentAnalysisView(recordedVideoSource: nil, isTestMode: false, viewModel: viewModel)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                if let setupGuideLabel = viewModel.setupGuideLabel, showSetupStateLabels {
                    Text(setupGuideLabel)
                        .font(.largeTitle)
                        .padding()
                        .background(.thinMaterial, in: .rect(cornerRadius: 10))
                        .foregroundStyle(.black)
                } else if viewModel.isRecordingPermissionDenied, showSetupStateLabels {
                    recordingDeniedLabel
                }
            }
            .overlay(alignment: .topLeading) {
                closeButton
            }
            .overlay(alignment: .topTrailing) {
                if !viewModel.isHoopPlaced || viewModel.manualHoopSelectorState == .inProgress {
                    manualHoopSelectionButtons
                }
            }
            .overlay(alignment: .bottom) {
                if showMetricsAndScore {
                    makeAndAttemptsView
                }
            }
            .overlay(alignment: .bottomLeading) {
                if let lastShotMetrics = viewModel.lastShotMetrics, showMetricsAndScore {
                    VStack(alignment: .leading) {
                        Text("Release Angel: ")
//                            .zIndex(999)
                            .foregroundStyle(.white)
                        +
                        Text(lastShotMetrics.releaseAngle.formatted())
                            .fontWeight(.bold)
                            .foregroundStyle(.orange)
                        
                        Text("Ball Speed: ")
//                            .zIndex(999)
                            .foregroundStyle(.white)
                        +
                        Text(lastShotMetrics.speed.formatted() + " MPH")
                            .fontWeight(.bold)
                            .foregroundStyle(.orange)
                    }
                    .padding()
                }
            }
            .overlay(alignment: .bottomTrailing) {
                // finish game button
                if !viewModel.isFinishButtonPressed, viewModel.isHoopPlaced {
                    LongPressButton(duration: 0.4) {
                        viewModel.isFinishButtonPressed = true
                        shotPaths = viewModel.playerStats?.shotPaths ?? []
                    }
                }
            }
            .overlay {
                if showSetupStateLabels {
                    setupStatesView
                }
            }
            .overlay {
                if !shotPaths.isEmpty {
                    shotPathsView
                }
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
        
    }
}

#Preview {
    ContentView()
}

/*
 .overlay(alignment: .topTrailing) {
     Button("Set") {
         manualSelectedHoopRect = Path { path in
             path.addLines(
                 [
                     CGPoint(
                         x: hoopTopLeftPosition.x,
                         y: hoopTopLeftPosition.y
                     ),
                     CGPoint(
                         x: hoopTopRightPosition.x,
                         y: hoopTopRightPosition.y
                     ),
                     CGPoint(
                         x: hoopBottomRightPosition.x,
                         y: hoopBottomRightPosition.y
                     ),
                     CGPoint(
                         x: hoopBottomLeftPosition.x,
                         y: hoopBottomLeftPosition.y
                     ),
                     CGPoint(
                         x: hoopTopLeftPosition.x,
                         y: hoopTopLeftPosition.y
                     )
                 ]
             )
         }
         .boundingRect
     }
     .buttonStyle(.borderedProminent)
     .tint(.green)
     .font(.headline.smallCaps())
     .padding()
 }
 .overlay {
     Path { path in
         path.addLines([
             hoopTopLeftPosition,
             hoopTopRightPosition,
             hoopBottomRightPosition,
             hoopBottomLeftPosition,
             hoopTopLeftPosition
         ])
     }
     .stroke(.purple, lineWidth: 3)
 }
 .overlay {
     Circle()
           .fill(Color.blue)
           .frame(width: 20, height: 20)
           .position(hoopTopLeftPosition)
           .gesture(
             DragGesture(minimumDistance: 0, coordinateSpace: .local)
               .onChanged { gesture in
                   hoopTopLeftPosition = gesture.location
                   hoopBottomLeftPosition.x = gesture.location.x
                   hoopTopRightPosition.y = gesture.location.y
               }
           )
     
     Circle()
           .fill(Color.blue)
           .frame(width: 20, height: 20)
           .position(hoopTopRightPosition)
           .gesture(
             DragGesture(minimumDistance: 0, coordinateSpace: .local)
               .onChanged { gesture in
                   hoopTopRightPosition = gesture.location
                   hoopBottomRightPosition.x = gesture.location.x
                   hoopTopLeftPosition.y = gesture.location.y
               }
           )
     
     Circle()
           .fill(Color.blue)
           .frame(width: 20, height: 20)
           .position(hoopBottomLeftPosition)
           .gesture(
             DragGesture(minimumDistance: 0, coordinateSpace: .local)
               .onChanged { gesture in
                   hoopBottomLeftPosition = gesture.location
                   hoopTopLeftPosition.x = gesture.location.x
                   hoopBottomRightPosition.y = gesture.location.y
               }
           )
     
     Circle()
           .fill(Color.blue)
           .frame(width: 20, height: 20)
           .position(hoopBottomRightPosition)
           .gesture(
             DragGesture(minimumDistance: 0, coordinateSpace: .local)
               .onChanged { gesture in
                   hoopBottomRightPosition = gesture.location
                   hoopBottomLeftPosition.y = gesture.location.y
                   hoopTopRightPosition.x = gesture.location.x
               }
           )
 }
 */
