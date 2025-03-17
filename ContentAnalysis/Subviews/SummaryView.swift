//
//  SwiftUIView.swift
//  BasketballAnalyzer
//
//  Created by Alpay Calalli on 05.02.25.
//

import ReplayKit
import SwiftUI

struct SummaryView: View {
   @State private var showPreviewController = false
   
   let previewVC: RPPreviewViewController?
   
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
         .map { $0.description }
      )
   }
   
   init(previewVC: RPPreviewViewController?) {
      self.previewVC = previewVC
      self.makesCount = 0
      self.attemptsCount = 0
      self.mostMissReason = ""
      self.avgReleaseAngle = 0
      self.avgBallSpeed = 0
   }
   
   @State private var hideStats = false
   
   var body: some View {
      content
         .opacity(hideStats ? 0 : 1)
         .fullScreenCover(isPresented: $showPreviewController, onDismiss: {
            print("preview dismissed")
         }) {
            if let previewVC {
               RPPreviewView(previewVC: previewVC)
                  .ignoresSafeArea()
            }
         }
         .overlay(alignment: .bottomLeading) {
            Button(hideStats ? "Show Stats" : "Hide Stats") {
               hideStats.toggle()
            }
            .padding()
            .tint(.blue)
            .buttonBorderShape(.capsule)
         }
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

extension SummaryView {
   private var content: some View {
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
         HStack {
            Spacer()
            Button("Export Session") {
               guard previewVC != nil else { return }
               showPreviewController = true
            }
            .disabled(previewVC == nil)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(previewVC == nil ? Color.gray.opacity(0.6) : Color.green)
            .foregroundStyle(.white)
            //                .fontWeight(.bold)
            .padding()
         }
      }
   }
}

struct SummaryStatView: View {
   let title: String
   let subtitle: String
   
   let isBigger: Bool
   
   init(title: String, subtitle: String, isBigger: Bool = false) {
      self.title = title
      self.subtitle = subtitle
      self.isBigger = isBigger
   }
   
   init(_ title: String, _ subtitle: String, isBigger: Bool = false) {
      self.title = title
      self.subtitle = subtitle
      self.isBigger = isBigger
   }
   
   var body: some View {
      VStack(alignment: .center) {
         Text(title)
            .font(isBigger ? .system(size: 90) : .system(size: 50))
            .fontWeight(.bold)
         Text(subtitle)
            .font(.largeTitle)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
      }
      .foregroundStyle(.white)
   }
}

struct iPhoneSummaryStatView: View {
   let title: String
   let subtitle: String
   
   let isBigger: Bool
   
   init(title: String, subtitle: String, isBigger: Bool = false) {
      self.title = title
      self.subtitle = subtitle
      self.isBigger = isBigger
   }
   
   init(_ title: String, _ subtitle: String, isBigger: Bool = false) {
      self.title = title
      self.subtitle = subtitle
      self.isBigger = isBigger
   }
   
   var body: some View {
      VStack(alignment: .center) {
         Text(title)
            .font(.largeTitle)
            .fontWeight(.bold)
         Text(subtitle)
            .font(.title2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
      }
      .foregroundStyle(.white)
   }
}

struct iPhoneSummaryView: View {
   @State private var showPreviewController = false
   
   let previewVC: RPPreviewViewController?
   
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
         .map { $0.description }
      )
   }
   
   init(previewVC: RPPreviewViewController?) {
      self.previewVC = previewVC
      self.makesCount = 0
      self.attemptsCount = 0
      self.mostMissReason = ""
      self.avgReleaseAngle = 0
      self.avgBallSpeed = 0
   }
   
   @State private var hideStats = false
   
   var body: some View {
      content
         .opacity(hideStats ? 0 : 1)
         .fullScreenCover(isPresented: $showPreviewController, onDismiss: {
            print("preview dismissed")
         }) {
            if let previewVC {
               RPPreviewView(previewVC: previewVC)
                  .ignoresSafeArea()
            }
         }
         .overlay(alignment: .bottomLeading) {
            Button(hideStats ? "Show Stats" : "Hide Stats") {
               hideStats.toggle()
            }
            .padding()
            .tint(.blue)
            .buttonBorderShape(.capsule)
            //                .foregroun
         }
   }
}

extension iPhoneSummaryView {
   private var content: some View {
      VStack(spacing: 30) {
         Spacer()
         HStack(spacing: 40) {
            iPhoneSummaryStatView(makesCount.formatted(), "makes", isBigger: true)
            Text("|").font(.largeTitle).foregroundStyle(.white)
            iPhoneSummaryStatView(attemptsCount.formatted(), "attempts", isBigger: true)
            Text("|").font(.largeTitle).foregroundStyle(.white)
            iPhoneSummaryStatView(String(format: "%.0f", shotAccuracy) + " %", "accuracy", isBigger: true)
         }
         .padding(.top, 30)
         //            Spacer()
         
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
         }.padding(.top)
         
         Spacer()
         HStack {
            Spacer()
            Button("Export Session") {
               guard previewVC != nil else { return }
               showPreviewController = true
            }
            .disabled(previewVC == nil)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(previewVC == nil ? Color.gray.opacity(0.6) : Color.green)
            .foregroundStyle(.white)
            //                .fontWeight(.bold)
            .padding()
         }
      }
   }
}
