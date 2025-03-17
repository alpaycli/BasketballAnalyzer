//
//  SummaryStatView.swift
//  Splash30
//
//  Created by Alpay Calalli on 17.03.25.
//

import SwiftUI

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
