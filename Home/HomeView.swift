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

struct HomeView: View {
    
    // MARK: - ViewModel
    
    @State var viewModel = ContentViewModel()
    
    // MARK: - Navigation Triggers
    
    @State var isTestMode = false

    @State var showFileImporter = false
    @State var recordedVideoSource: AVAsset?
    
    @State var isLiveCameraSelected = false
    @State var isShowGuidesView = false
    
    // MARK: - Others
    
    @State var showPortraitAlert = false
   
    var pub = NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
    let editHoopTip = EditHoopTip()
    @Namespace private var namespace
    
    // MARK: - View Body
    
    var body: some View {
        NavigationStack {
            Group {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    padContent
                } else if UIDevice.current.userInterfaceIdiom == .phone {
                    phoneContent
                }
            }
            .disabled(showPortraitAlert || !(GameManager.shared.stateMachine.currentState is GameManager.InactiveState))
            .overlay {
                if showPortraitAlert {
                    portraitAlertView
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
                if GameManager.shared.stateMachine.currentState == nil {
                    GameManager.shared.stateMachine.enter(GameManager.InactiveState.self)
                }
                
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

            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.movie], onCompletion: { result in
                switch result {
                case let .success(url):
                    handleImportedVideoFileURL(url)
                case let .failure(error):
                    print("failure", error.localizedDescription)
                }
            })
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    HomeView()
        .colorScheme(.light)
}
