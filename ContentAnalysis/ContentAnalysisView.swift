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
            viewModel: viewModel
        )
                
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
}
