//
//  HomeView+DeviceVariants.swift
//  Splash30
//
//  Created by Alpay Calalli on 08.03.25.
//

import SwiftUI

// MARK: - Home View Device Variants
// ContentView's variants for iPad and iPhone
extension HomeView {
    var padContent: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 30) {
                GradientHomeItemView(
                    title: "Test Mode",
                    systemImage: "play",
                    bodyLabel: "Test with my sample video to speed up the judgement process",
                    buttonLabel: "Start Demo",
                    buttonAction: testModeTappedAction
                )
                HomeItemView(title: "Upload Video",
                             systemImage: "square.and.arrow.up",
                             bodyLabel: "Upload your basketball shooting video",
                             buttonLabel: "Choose File") { showFileImporter = true }
                
                HomeItemView(
                    title: "Live Camera",
                    systemImage: "video",
                    bodyLabel: "Get real-time feedback using your device's camera",
                    buttonLabel: "Start Capture",
                    buttonAction: liveCameraTappedAction
                )
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
    
    var phoneContent: some View {
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
            
            Button("Live Camera", systemImage: "video", action: liveCameraTappedAction)
            .foregroundStyle(.white)
            .fontWeight(.bold)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            
            Button("Test with a sample video", action: testModeTappedAction)
            .font(.title.smallCaps())
            .fontDesign(.rounded)
            .fontWeight(.bold)
            .foregroundStyle(.blue)
            .padding(.top)
            
            Spacer()
        }
    }
}
