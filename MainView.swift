//
//  MainView.swift
//  PlaygroundExploration
//
//  Created by Alpay Calalli on 16.12.24.
//

import TipKit
import Observation
import PhotosUI
import AVFoundation
import Vision
import SwiftUI

@Observable
class ContentViewModel {
    var hoopCenterPoint: CGPoint?
    
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
    var isVideoEnded = false
    
//    var hoopDetectionRequest: VNCoreMLRequest
    
    func reset() {
        manualHoopSelectorState = .none
        lastShotMetrics = nil
        playerStats = nil
        setupGuideLabel = nil
        setupStateModel = .init()
        isFinishButtonPressed = false
        isRecordingPermissionDenied = false
        isVideoEnded = false
    }
    
    var isHoopPlaced: Bool {
        setupStateModel.hoopDetected
    }
}

struct ContentView: View {
    
    // MARK: - ViewModel
    
    @State private var viewModel = ContentViewModel()
    
    // MARK: -
    
    private let editHoopTip = EditHoopTip()
    
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
        
    @State private var isShowGuidesView = false
    
    @State private var showPortraitAlert = false
    
    var showMetricsAndScore: Bool {
        !viewModel.isVideoEnded && !viewModel.isFinishButtonPressed
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
            .disabled(showPortraitAlert)
            .navigationDestination(isPresented: $isTestMode) {
                contentViewWithRecordedVideo(isTestMode: isTestMode)
                    .navigationTransition(.zoom(sourceID: "recordedVidedZoom", in: namespace))
                    .overlay {
                        if showPortraitAlert {
                            portraitAlertView
                        }
                    }
            }
            .navigationDestination(item: $recordedVideoSource) { item in
                contentViewWithRecordedVideo(item)
                    .navigationTransition(.zoom(sourceID: "recordedVidedZoom", in: namespace))
                    .overlay {
                        if showPortraitAlert {
                            portraitAlertView
                        }
                    }
            }
            .navigationDestination(isPresented: $isLiveCameraSelected) {
                contentViewWithLiveCamera
                    .navigationTransition(.zoom(sourceID: "liveCameraZoom", in: namespace))
                    .overlay {
                        if showPortraitAlert {
                            portraitAlertView
                        }
                    }
            }
            .fullScreenCover(isPresented: $isShowGuidesView) {
                NavigationStack {
                    SettingUpDeviceInstructionView(isShowGuidesView: $isShowGuidesView)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Dismiss", systemImage: "xmark") {
                                    isShowGuidesView = false
                                }
                            }
                        }
                }
            }
            .onReceive(pub) { c in
                print("video ended in view", c.name.rawValue, c.name)
                viewModel.isVideoEnded = true
                //                shotPaths = viewModel.playerStats?.shotPaths ?? []
            }
            .onAppear {
                guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
                withAnimation {
                    showPortraitAlert = scene.interfaceOrientation.isPortrait
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
                withAnimation {
                    showPortraitAlert = scene.interfaceOrientation.isPortrait
                    if scene.interfaceOrientation.isPortrait {
                        isTestMode = false
                        recordedVideoSource = nil
                        isLiveCameraSelected = false
                    }
                }
            }
            .overlay {
                if showPortraitAlert {
                    portraitAlertView
                }
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

// MARK: - Devices

extension ContentView {
    private var padContent: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 30) {
                GradientHomeItemView(title: "Test Mode", systemImage: "play", bodyLabel: "Test with my sample video to speed up the judgement process", buttonLabel: "Start Demo") {
                    GameManager.shared.stateMachine.enter(GameManager.SetupCameraState.self)
                    isTestMode = true
                }
                HomeItemView(title: "Upload Video",
                             systemImage: "square.and.arrow.up", 
                             bodyLabel: "Upload your basketball shooting video", 
                             buttonLabel: "Choose File") { showFileImporter = true }
                
                HomeItemView(title: "Live Camera", systemImage: "video", bodyLabel: "Get real-time feedback using your device's camera", buttonLabel: "Start Capture") { 
                    GameManager.shared.reset()
                    GameManager.shared.stateMachine.enter(GameManager.SetupCameraState.self)
                    
                    isLiveCameraSelected = true
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.formBackground)
        .overlay(alignment: .topTrailing) { 
            Button("Show Guides") {
                isShowGuidesView = true
            }
            .font(.largeTitle)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.red)
            .foregroundStyle(.white)
            .fontWeight(.bold)
            .padding()
        }
    }
    
    private var phoneContent: some View {
        VStack {
            HStack {
                Spacer()
                NavigationLink {
                    SettingUpDeviceInstructionView(isShowGuidesView: $isShowGuidesView)
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

// MARK: - Contents

extension ContentView {
    private func contentViewWithRecordedVideo(_ item: AVAsset? = nil, isTestMode: Bool = false) -> some View {
        ContentAnalysisView(recordedVideoSource: item, isTestMode: isTestMode, viewModel: viewModel)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .overlay {
                if let point = viewModel.hoopCenterPoint {
                    Circle()
                        .fill(.clear)
                        .popoverTip(editHoopTip, arrowEdge: .top)
                        .frame(width: 14)
                        .position(point)
                }
            }
            .overlay(alignment: .top) {
                if let setupGuideLabel = viewModel.setupGuideLabel, showSetupStateLabels {
                    Text(setupGuideLabel)
                        .font(.largeTitle)
                        .padding()
                        .background(.thinMaterial, in: .rect(cornerRadius: 10))
                        .foregroundStyle(.black)
                } else if viewModel.isRecordingPermissionDenied {
                    recordingDeniedLabel
                }
            }
            .overlay(alignment: .topTrailing) {
                closeButton
                    .padding()
            }
            .overlay(alignment: .bottomTrailing) {
                if !viewModel.isHoopPlaced || viewModel.manualHoopSelectorState == .inProgress {
                    manualHoopSelectionButtons
                        .padding(.trailing)
//                        .padding()
                }
            }
            .overlay(alignment: .bottom) {
                if showMetricsAndScore {
                    makeAndAttemptsView
                }
            }
            .overlay(alignment: .bottomLeading) {
                if let lastShotMetrics = viewModel.lastShotMetrics, showMetricsAndScore {
                    lastShotMetricsView(lastShotMetrics)
                }
            }
            .overlay {
                if showSetupStateLabels {
                    setupStatesView
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
                } else if viewModel.isRecordingPermissionDenied {
                    recordingDeniedLabel
                }
            }
            .overlay(alignment: .topLeading) {
                closeButton
                    .padding()
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
                    lastShotMetricsView(lastShotMetrics)
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
            .toolbarVisibility(.hidden, for: .navigationBar)
        
    }
    
    private var mockContentViewWithLiveCamera: some View {
        ContentAnalysisView(recordedVideoSource: nil, isTestMode: true, viewModel: viewModel)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                if let setupGuideLabel = viewModel.setupGuideLabel, showSetupStateLabels {
                    Text(setupGuideLabel)
                        .font(.largeTitle)
                        .padding()
                        .background(.thinMaterial, in: .rect(cornerRadius: 10))
                        .foregroundStyle(.black)
                } else if viewModel.isRecordingPermissionDenied {
                    recordingDeniedLabel
                }
            }
            .overlay(alignment: .topLeading) {
                closeButton
                    .padding()
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
                    lastShotMetricsView(lastShotMetrics)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                // finish game button
//                if !viewModel.isFinishButtonPressed, viewModel.isHoopPlaced {
                    LongPressButton(duration: 0.4) {
                        viewModel.isFinishButtonPressed = true
                        shotPaths = viewModel.playerStats?.shotPaths ?? []
                    }
//                }
            }
            .overlay {
                if showSetupStateLabels {
                    setupStatesView
                }
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
        
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
//            GameManager.shared.stateMachine.enter(GameManager.InactiveState.self)
        }
        .padding()
        .labelStyle(.iconOnly)
        .font(.largeTitle)
        .background(.gray, in: .circle)
    }
    
    private var portraitAlertView: some View {
        VStack {
            Image(systemName: "rectangle.landscape.rotate")
                .font(.system(size: 80))
                .padding()
                .symbolEffect(.breathe)
            Text("Rotate Device to Landscape")
                .font(.title)
        }
        .fontWeight(.bold)
        .frame(width: 300, height: 300, alignment: .center)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 25, style: .continuous))
        .shadow(radius: 15)
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
    
    private var manualHoopSelectionButtons: some View {
        HStack {
            if viewModel.manualHoopSelectorState == .inProgress {
                Button("Cancel") {
                    viewModel.manualHoopSelectorState = .none
                }
                .buttonStyle(.borderless)
                .tint(.green)
                .font(.headline.smallCaps())
            }
            Button(viewModel.manualHoopSelectorState == .inProgress ? "Set" : "Set Hoop") {
                if viewModel.manualHoopSelectorState == .inProgress {
                    viewModel.manualHoopSelectorState = .set
                } else {
                    viewModel.manualHoopSelectorState = .inProgress
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .font(.headline.smallCaps())
        }
    }
    
    private var recordingDeniedLabel: some View {
        Label("Recording denied", systemImage: "stop.circle")
            .padding(5)
            .background(.thinMaterial, in: .rect(cornerRadius: 10))
            .foregroundStyle(.red)
            .font(.headline.smallCaps())
    }
    
    @ViewBuilder
    private func lastShotMetricsView(_ metrics: ShotMetrics) -> some View {
        VStack(alignment: .leading) {
            Text("Release Angel: ")
            +
            Text(metrics.releaseAngle.formatted() + "°")
                .fontWeight(.bold)
//                            .foregroundStyle(.orange)
            
//                        Text("Ball Speed: ")
//                            .foregroundStyle(.white)
//                        +
//                        Text(lastShotMetrics.speed.formatted() + " MPH")
//                            .fontWeight(.bold)
//                            .foregroundStyle(.orange)
            
            Text(metrics.shotResult.description)
                .fontWeight(.bold)
//            if metrics.shotResult != .score {
//                Text("Miss Reason: ")
//                +
//                Text(metrics.shotResult.description)
//                    .fontWeight(.bold)
////                                .foregroundStyle(.orange)
//            }
        }
        .foregroundStyle(.white)
        .padding()
    }
}

#Preview {
    ContentView()
        .colorScheme(.light)
}

/// Convert Vision's normalized coordinates to screen coordinates
func convertVisionPoint(_ point: CGPoint) -> CGPoint {
    let screenSize = UIScreen.main.bounds.size
    let y = point.x * screenSize.height
    let x = point.y * screenSize.width
    return CGPoint(x: x, y: y)
}

/// Convert Vision's normalized coordinates to screen coordinates
func viewPointConverted(fromNormalizedContentsPoint normalizedPoint: CGPoint) -> CGPoint {
    let videoRect = UIScreen.main.bounds
    
    let flippedPoint = normalizedPoint.applying(.verticalFlip)
    
    let convertedPoint = CGPoint(x: videoRect.origin.x + flippedPoint.x * videoRect.width,
                                 y: videoRect.origin.y + flippedPoint.y * videoRect.height)
    return convertedPoint
}
