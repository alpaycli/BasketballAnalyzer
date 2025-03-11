//
//  ContentAnalysisViewController.swift
//  PlaygroundExploration
//
//  Created by Alpay Calalli on 18.12.24.
//

import ReplayKit
import SwiftUI
import UIKit
import AVFoundation
import Vision

struct ContentAnalysisView: UIViewControllerRepresentable {
    let recordedVideoSource: AVAsset?
    let isTestMode: Bool
    @Bindable var viewModel: ContentViewModel
    
    func makeUIViewController(context: Context) -> ContentAnalysisViewController {
        let vc = ContentAnalysisViewController(
            recordedVideoSource: isTestMode ? getTestVideo() : recordedVideoSource,
            isTestMode: isTestMode,
            viewModel: viewModel,
            delegate: context.coordinator,
            cameraVCDelegate: context.coordinator
        )
        
        context.coordinator.vc = vc
        
        return vc
    }
    
    func updateUIViewController(_ uiViewController: ContentAnalysisViewController, context: Context) {
        
        if viewModel.isFinishButtonPressed {
            uiViewController.finishGame()
        }
        
        switch viewModel.manualHoopSelectorState {
        case .none:
            Task { await uiViewController.cancelManualHoopSelectionAction() }
        case .inProgress:
            uiViewController.inProgressManualHoopSelectionAction()
        case .set:
            Task { await uiViewController.setHoop() }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CameraViewControllerOutputDelegate, ContentAnalysisVCDelegate {
        
        let parent: ContentAnalysisView
        var vc: ContentAnalysisViewController?
        
        init(_ parent: ContentAnalysisView) {
            self.parent = parent
        }
        
        // Buffers from camera feed are sent here for analysis.
        func cameraViewController(_ controller: CameraViewController, didReceiveBuffer buffer: CMSampleBuffer, orientation: CGImagePropertyOrientation) {
            vc?.cameraVCDelegateAction(controller, didReceiveBuffer: buffer, orientation: orientation)
        }
        
        func showLastShowMetrics(metrics: ShotMetrics, playerStats: PlayerStats) {
            parent.viewModel.lastShotMetrics = metrics
            parent.viewModel.playerStats = playerStats
        }
        
        
    }
}
