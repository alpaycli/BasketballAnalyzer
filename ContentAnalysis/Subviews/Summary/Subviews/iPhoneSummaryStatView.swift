//
//  iPhoneSummaryStatView.swift
//  Splash30
//
//  Created by Alpay Calalli on 17.03.25.
//

import SwiftUI

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
