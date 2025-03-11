//
//  HomeView+AnalysisViewVariants.swift
//  Splash30
//
//  Created by Alpay Calalli on 08.03.25.
//

import AVFoundation
import SwiftUI

// MARK: - ContentAnalysisView Variants
// These are variants of ContentAnalysisView depends on user input.
// Such as:
// Test Mode with pre-uploaded video
// Live Camera
// Upload recoreded video from device
extension HomeView {
    func contentViewWithRecordedVideo(_ item: AVAsset? = nil, isTestMode: Bool = false) -> some View {
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
    
    var contentViewWithLiveCamera: some View {
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
    
    var mockContentViewWithLiveCamera: some View {
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
