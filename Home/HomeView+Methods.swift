//
//  HomeView+Methods.swift
//  Splash30
//
//  Created by Alpay Calalli on 08.03.25.
//

import AVFoundation
import SwiftUI

// MARK: - Methods

extension HomeView { 
    func handleImportedVideoFileURL(_ url: URL) {
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
            GameManager.shared.reset()
            viewModel.reset()
            GameManager.shared.stateMachine.enter(GameManager.SetupCameraState.self)
            await MainActor.run {
                recordedVideoSource = AVURLAsset(url: selectedFileURL)
            }
        }
    }
    
    func liveCameraTappedAction() {
        GameManager.shared.reset()
        viewModel.reset()
        GameManager.shared.stateMachine.enter(GameManager.SetupCameraState.self)
        
        isLiveCameraSelected = true
    }
    
    func testModeTappedAction() {
        GameManager.shared.reset()
        viewModel.reset()
        GameManager.shared.stateMachine.enter(GameManager.SetupCameraState.self)
        
        isTestMode = true
    }
}

/// Convert Vision's normalized coordinates to screen coordinates
func viewPointConverted(fromNormalizedContentsPoint normalizedPoint: CGPoint) -> CGPoint {
    let videoRect = UIScreen.main.bounds
    
    let flippedPoint = normalizedPoint.applying(.verticalFlip)
    
    let convertedPoint = CGPoint(x: videoRect.origin.x + flippedPoint.x * videoRect.width,
                                 y: videoRect.origin.y + flippedPoint.y * videoRect.height)
    return convertedPoint
}
