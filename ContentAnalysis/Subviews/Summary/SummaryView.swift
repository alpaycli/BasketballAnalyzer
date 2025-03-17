//
//  SummaryView.swift
//  BasketballAnalyzer
//
//  Created by Alpay Calalli on 05.02.25.
//

import ReplayKit
import SwiftUI

struct SummaryView: View {
   @Environment(\.dismiss) var dismiss
   @State private var isDismiss = false
   @State private var showPreviewController = false
   
   let previewVC: RPPreviewViewController?
   
   let makesCount: Int
   let attemptsCount: Int
   var shotAccuracy: Double {
      (Double(makesCount) / Double(attemptsCount)) * 100
   }
   let mostMissReason: String?
   let avgReleaseAngle: Double?
   let avgBallSpeed: Double?
   
   @State private var hideStats = false
   
   var body: some View {
      Group {
         if UIDevice.current.userInterfaceIdiom == .pad {
            padContent
         } else if UIDevice.current.userInterfaceIdiom == .phone {
            phoneContent
         }
      }
      .opacity(hideStats ? 0 : 1)
      .overlay(alignment: .bottomLeading) { toggleSummaryViewButton }
      .fullScreenCover(isPresented: $showPreviewController) {
         if let previewVC {
            RPPreviewView(previewVC: previewVC)
               .ignoresSafeArea()
         }
      }
   }
}

// MARK: - Contents

extension SummaryView {
   private var padContent: some View {
      VStack(spacing: 30) {
         Spacer()
         HStack(spacing: 40) {
            SummaryStatView(makesCount.formatted(), "makes", isBigger: true)
            Text("|").font(.system(size: 60)).foregroundStyle(.white)
            SummaryStatView(attemptsCount.formatted(), "attempts", isBigger: true)
            Text("|").font(.system(size: 60)).foregroundStyle(.white)
            SummaryStatView(String(format: "%.0f", shotAccuracy) + " %", "accuracy", isBigger: true)
         }
         Spacer()
         
         HStack(spacing: 140) {
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
      }
      .frame(maxWidth: .infinity)
      .overlay(alignment: .bottomTrailing) { exportSessionButton }
   }
   
   private var phoneContent: some View {
      VStack(spacing: 30) {
         Spacer()
         HStack(spacing: 40) {
            iPhoneSummaryStatView(makesCount.formatted(), "makes", isBigger: true)
            Text("|").font(.largeTitle).foregroundStyle(.white)
            iPhoneSummaryStatView(attemptsCount.formatted(), "attempts", isBigger: true)
            Text("|").font(.largeTitle).foregroundStyle(.white)
            iPhoneSummaryStatView(String(format: "%.0f", shotAccuracy) + " %", "accuracy", isBigger: true)
         }
//         .padding(.top, 30)
         
         HStack(spacing: 40) {
            if let mostMissReason {
               iPhoneSummaryStatView(mostMissReason, "most miss \n reason")
            }
            if let avgReleaseAngle {
               iPhoneSummaryStatView(avgReleaseAngle.formatted() + "°", "avg. release \n angle")
            }
            if let avgBallSpeed {
               iPhoneSummaryStatView(avgBallSpeed.formatted() + " MPH", "avg. ball \n speed")
            }
         }
         .padding(.top)
         
         Spacer()
         Spacer()
         
      }
      .frame(maxWidth: .infinity)
      .overlay(alignment: .bottomTrailing) { exportSessionButton }
   }
}

// MARK: - View Components

extension SummaryView {
   private var exportSessionButton: some View {
      Button("Export Session") {
         guard previewVC != nil else { return }
         showPreviewController = true
      }
      .disabled(previewVC == nil)
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .tint(previewVC == nil ? Color.gray.opacity(0.6) : Color.green)
      .foregroundStyle(.white)
      .padding()
   }
   
   private var toggleSummaryViewButton: some View {
      Button(hideStats ? "Show Stats" : "Hide Stats") {
         hideStats.toggle()
      }
      .padding()
      .tint(.blue)
      .buttonBorderShape(.capsule)
   }
}

// MARK: - Inits

extension SummaryView {
   init(
      previewVC: RPPreviewViewController?,
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
      previewVC: RPPreviewViewController?,
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
               .map(\.description)
      )
   }
   
}

#Preview {
   ZStack {
      Color.black.opacity(0.6)
         .ignoresSafeArea()
      
      SummaryView(
         previewVC: nil,
         makesCount: 5,
         attemptsCount: 12,
         mostMissReason: "Short",
         avgReleaseAngle: 90,
         avgBallSpeed: 10
      )
   }
}
