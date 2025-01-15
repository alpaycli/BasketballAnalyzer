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
    
    @State private var boardRect: CGPath?
    
    // MARK: -
    
    @State private var recordedVideoSource: AVAsset?
    @State private var isLiveCameraSelected = false
    
    @State private var showFileImporter = false
    @State private var photo: PhotosPickerItem?
    
    // MARK: - Metrics and Stats
    
    @State private var lastShotMetrics: ShotMetrics? = nil
    @State private var playerStats: PlayerStats? = nil
    
    var lastShotMetricsBinding: Binding<ShotMetrics?> {
        .init {
            lastShotMetrics
        } set: { newValue in
            print("bura lastshotmetrics", "salam")
            lastShotMetrics = newValue
            showShotResultLabel = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                showShotResultLabel = false
            }
        }
    }
    
    // MARK: - Summary

    @State private var showShotResultLabel = false
    
    var body: some View {
        NavigationStack {
            VStack {
                Button("Import video") { showFileImporter = true }
                
                Button("Live Camera") {
                    GameManager.shared.reset()
                    GameManager.shared.stateMachine.enter(GameManager.SetupCameraState.self)
                    
                    // to not see previous videos last shot metrics on the initial
                    lastShotMetrics = nil
                    playerStats = nil
                    
                    
                    isLiveCameraSelected = true
                }
            }
            .navigationDestination(item: $recordedVideoSource) { item in
                contentViewWithRecordedVideo(item)
            }
            .navigationDestination(isPresented: $isLiveCameraSelected) {
                contentViewWithLiveCamera
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.movie], onCompletion: { result in
                switch result {
                case let .success(url):
                    handleImportedVideoFileURL(url)
                case let .failure(error):
                    print("failure", error.localizedDescription)
                }
            })
//            .photosPicker(isPresented: $showFileImporter, selection: $photo, matching: .videos)
//            .onChange(of: photo) { oldValue, newValue in
//                if let newValue {
//                    handlePhotoPickerSelection(newValue)
//                }
//            }
        }
    }
}

// MARK: - Methods

extension MainView {
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
                
                // to not see previous videos last shot metrics on the initial
                lastShotMetrics = nil
                playerStats = nil
                
                recordedVideoSource = AVURLAsset(url: selectedFileURL)
            }
        }
    }
}

// MARK: - UI components

extension MainView {
    private var closeButton: some View {
        Button("Close", systemImage: "xmark") {
            recordedVideoSource = nil
            isLiveCameraSelected = false
        }
        .padding()
        .labelStyle(.iconOnly)
        .font(.largeTitle)
        .background(.gray, in: .circle)
    }
    
    private var makeAndAttemptsView: some View {
        HStack {
            VStack {
                Text(playerStats?.totalScore.formatted() ?? "0")
                    .font(.largeTitle)
                    .fontDesign(.monospaced)
                    .contentTransition(.numericText())
                Text("make")
                    .font(.headline.uppercaseSmallCaps())
//                            .foregroundStyle(.secondary)
            }
            Text("/")
                .font(.largeTitle)
                .padding(.horizontal)
            VStack {
                Text(playerStats?.shotCount.formatted() ?? "0")
                    .font(.largeTitle)
                    .fontDesign(.monospaced)
                    .contentTransition(.numericText())
                Text("attempt")
                    .font(.headline.uppercaseSmallCaps())
//                            .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.white.gradient)
    }
}

// MARK: -

extension MainView {
    private func contentViewWithRecordedVideo(_ item: AVAsset) -> some View {
        ContentAnalysisView(recordedVideoSource: item, lastShotMetrics: lastShotMetricsBinding, playerStats: $playerStats.animation())
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .overlay(alignment: .bottomTrailing) {
                if let lastShotMetrics {
                    VStack {
                        Text(lastShotMetrics.releaseAngle.formatted())
                            .zIndex(999)
                            .foregroundStyle(.white)
                        
                        Text("Ball Speed: " + lastShotMetrics.speed.formatted() + " MPH")
                            .zIndex(999)
                            .foregroundStyle(.white)
                    }
                    .padding()
                }
            }
            .overlay(alignment: .topLeading) {
                closeButton
            }
            .overlay(alignment: .bottom) {
                makeAndAttemptsView
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
    }
    
    private var contentViewWithLiveCamera: some View {
        ContentAnalysisView(recordedVideoSource: nil, lastShotMetrics: lastShotMetricsBinding, playerStats: $playerStats.animation())
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .overlay(alignment: .bottomTrailing) {
                if let lastShotMetrics {
                    VStack {
                        Text(lastShotMetrics.releaseAngle.formatted())
                            .zIndex(999)
                            .foregroundStyle(.white)
                        
                        Text("Ball Speed: " + lastShotMetrics.speed.formatted() + " MPH")
                            .zIndex(999)
                            .foregroundStyle(.white)
                    }
                    .padding()
                }
            }
            .overlay(alignment: .topLeading) {
                closeButton
            }
            .overlay(alignment: .bottom) {
                makeAndAttemptsView
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
        
    }
}
