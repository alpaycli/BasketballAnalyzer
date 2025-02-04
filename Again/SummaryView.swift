//
//  SummaryView.swift
//  BasketballAnalyzer
//
//  Created by Alpay Calalli on 05.02.25.
//

import ReplayKit
import SwiftUI

struct SummaryView: View {
    @State private var showPreviewController = false
    
    let previewVC: RPPreviewViewController
    
    @Environment(\.dismiss) var dismiss
    @State private var isDismiss = false
    
    let makesCount: Int
    let attemptsCount: Int
    var shotAccuracy: Double {
        (Double(makesCount) / Double(attemptsCount)) * 100
    }
    
    let mostMissReason: String?
    let avgReleaseAngle: Double?
    let avgBallSpeed: Double?
    
    init(
        previewVC: RPPreviewViewController,
        makesCount: Int,
        attemptsCount: Int,
        mostMissReason: String,
        avgReleaseAngle: Double,
        avgBallSpeed: Double
    ) {
        self.previewVC = previewVC
        self.makesCount = makesCount
        self.attemptsCount = attemptsCount
        self.mostMissReason = mostMissReason
        self.avgReleaseAngle = avgReleaseAngle
        self.avgBallSpeed = avgBallSpeed
    }
    
    init(
        previewVC: RPPreviewViewController,
        playerStats: PlayerStats
    ) {
        self.previewVC = previewVC
        self.makesCount = playerStats.totalScore
        self.attemptsCount = playerStats.shotCount
        self.mostMissReason = playerStats.mostMissReason
        self.avgReleaseAngle = playerStats.avgReleaseAngle
        self.avgBallSpeed = playerStats.avgSpeed
        
        print("allrelease angles", playerStats.allReleaseAngles)
        print("all speeds", playerStats.allSpeeds)
        print("all miss reasons",
              playerStats.shotResults
                .filter { if case .miss = $0 { return true }; return false }
                .map { $0.description }
        )
    }
    
    init(previewVC: RPPreviewViewController) {
        self.previewVC = previewVC
        self.makesCount = 0
        self.attemptsCount = 0
        self.mostMissReason = ""
        self.avgReleaseAngle = 0
        self.avgBallSpeed = 0
    }
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            Spacer()
            HStack(spacing: 20) {
                SummaryStatView(makesCount.formatted(), "makes")
                Text("|").font(.largeTitle).foregroundStyle(.white)
                SummaryStatView(attemptsCount.formatted(), "attempts")
                Text("|").font(.largeTitle).foregroundStyle(.white)
                SummaryStatView(String(format: "%.0f", shotAccuracy) + "%", "accuracy")
            }
            
            HStack(spacing: 40) {
                if let mostMissReason {
                    SummaryStatView(mostMissReason, "most miss \n reason")
                }
                if let avgReleaseAngle {
                    SummaryStatView(avgReleaseAngle.formatted() + "°", "avg. release \n angle")
                }
                if let avgBallSpeed {
                    SummaryStatView(avgBallSpeed.formatted() + " MPH", "avg. ball \n speed")
                }
            }
            
            Spacer()
            HStack {
                Spacer()
                Button("Save Session") {
                    showPreviewController = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.green)
                .foregroundStyle(.white)
                .fontWeight(.bold)
                .padding()
            }
        }
        .fullScreenCover(isPresented: $showPreviewController, onDismiss: {
            print("preview dismissed")
        }) {
            RPPreviewView(previewVC: previewVC)
                .ignoresSafeArea()
        }
    }
}

#Preview {
    ZStack {
        Color.black.opacity(0.6)
            .ignoresSafeArea()
            
        SummaryView(previewVC: .init())
    }
}

struct SummaryStatView: View {
    let title: String
    let subtitle: String
    
    init(title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
    }
    
    init(_ title: String, _ subtitle: String) {
        self.title = title
        self.subtitle = subtitle
    }
    
    var body: some View {
        VStack(alignment: .center) {
            Text(title)
                .font(.largeTitle)
                .fontWeight(.bold)
            Text(subtitle)
                .font(.title)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.white)
    }
}
