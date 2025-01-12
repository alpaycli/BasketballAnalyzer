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
                
                ContentAnalysisView(recordedVideoSource: recordedVideoSource, lastShotMetrics: lastShotMetricsBinding, playerStats: $playerStats)
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
                            Text(lastShotMetrics.shotResult.description)
                                .font(.largeTitle)
                                .zIndex(999)
                                .animation(.easeInOut, value: showShotResultLabel)
                                .transition(.scale)
                        }
                    }
                    .overlay {
                        if let playerStats {
                            Text("Game is Over, Here is your Summary.")
                                .font(.largeTitle)
                                .zIndex(999)
                                .animation(.easeInOut, value: playerStats != nil)
                                .transition(.scale)
                        }
                    }
                
//                CameraView(recordedVideoAsset: recordedVideoSource)
//                    .onTapGesture {
//                        showFileImporter = true
//                    }
            } else if isLiveCameraSelected {
                ContentAnalysisView(recordedVideoSource: nil, lastShotMetrics: lastShotMetricsBinding, playerStats: $playerStats)
            } else {
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
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .overlay(alignment: .topLeading) {
            if recordedVideoSource != nil || isLiveCameraSelected {
                closeButton
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
//        .photosPicker(isPresented: $showFileImporter, selection: $photo, matching: .videos)
//        .onChange(of: photo) { oldValue, newValue in
//            if let newValue {
//                handlePhotoPickerSelection(newValue)
//            }
//        }
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
}
