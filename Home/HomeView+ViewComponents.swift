//
//  HomeView+UI.swift
//  Splash30
//
//  Created by Alpay Calalli on 07.03.25.
//

import SwiftUI

// MARK: - View Components

extension HomeView {
     var closeButton: some View {
        Button("Close", systemImage: "xmark") {
            recordedVideoSource = nil
            isLiveCameraSelected = false
            isTestMode = false
        }
        .padding()
        .labelStyle(.iconOnly)
        .font(.largeTitle)
        .background(.thinMaterial, in: .circle)
    }
    
     var portraitAlertView: some View {
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
    
     var makeAndAttemptsView: some View {
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
    
     var setupStatesView: some View {
        VStack(alignment: .leading) {
            Text("Hoop Detected: " + "\(viewModel.setupStateModel.hoopDetected ? "✅" : "❌")")
//            Text("Hoop Contours Detected: " + "\(viewModel.setupStateModel.hoopContoursDetected ? "✅" : "❌")")
            Text("Player Detected: " + "\(viewModel.setupStateModel.playerDetected ? "✅" : "❌")")
        }
        .fontDesign(.monospaced)
        .foregroundStyle(.black)
        .padding()
        //                .frame(width: 200, height: 100)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 15))
    }
    
     var manualHoopSelectionButtons: some View {
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
    
     var recordingDeniedLabel: some View {
        Label("Recording denied", systemImage: "stop.circle")
            .padding(5)
            .background(.thinMaterial, in: .rect(cornerRadius: 10))
            .foregroundStyle(.red)
            .font(.headline.smallCaps())
    }
    
    @ViewBuilder
    func lastShotMetricsView(_ metrics: ShotMetrics) -> some View {
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
