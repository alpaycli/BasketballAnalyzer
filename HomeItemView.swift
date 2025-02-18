//
//  SwiftUIView.swift
//  SwishVision30
//
//  Created by Alpay Calalli on 18.02.25.
//

import SwiftUI

struct HomeItemView: View {
    let title: String
    let systemImage: String
    let bodyLabel: String
    let buttonLabel: String
    let buttonAction: () -> ()
    
    @Environment(\.colorScheme) var colorScheme
    var isDarkMode: Bool {
        colorScheme == .dark
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.formForeground)
            .frame(width: 400/*, height: 250*/)
            .containerRelativeFrame(.vertical, { length, _ in
                length / 4
            })
            .overlay {
                VStack(spacing: 10) {
                    Image(systemName: systemImage)
                        .font(.largeTitle)
                        .padding(.top)
                    Text(title)
                        .font(.title)
                    
                    Text(bodyLabel)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                    
                    Button(action: buttonAction) {
                        Text(buttonLabel)
                            .frame(maxWidth: .infinity, minHeight: 40, maxHeight: 40)
                            .background(isDarkMode ? .white : .black, in: .rect(cornerRadius: 10))
                            .foregroundStyle(isDarkMode ? Color.accentColor : Color.white)
                            .fontWeight(.bold)
                    }
                    .padding()
                }
                .minimumScaleFactor(0.6)
            }
            .shadow(radius: 1)
    }
}

struct GradientHomeItemView: View {
    let title: String
    let systemImage: String
    let bodyLabel: String
    let buttonLabel: String
    let buttonAction: () -> ()
    
    var body: some View {
        TimelineView(.animation) { timeline in
            RoundedRectangle(cornerRadius: 10)
                .fill(
//                    MeshGradient(
//                        width: 3,
//                        height: 3,
//                        locations: .points(<#T##[SIMD2<Float>]#>),
//                        colors: .colors(animatedColors(for: timeline.date))
//                    )
                    MeshGradient(
                      width: 3,
                      height: 3,
//                      points: [
//                        .init(0.00, 0.00),.init(0.50, 0.00),.init(1.00, 0.00),
//                        .init(0.00, 0.50),.init(0.61, 0.72),.init(1.00, 0.50),
//                        .init(0.00, 1.00),.init(0.50, 1.00),.init(1.00, 1.00)
//                      ],
                      locations: .points(points),
//                      colors: animatedColors(for: timeline.date),
                      colors: .colors(animatedColors(for: timeline.date)),
                      smoothsColors: true
                    )
                )
                .frame(width: 400/*, height: 250*/)
                .containerRelativeFrame(.vertical, { length, _ in
                    length / 4
                })
                .overlay {
                    VStack(spacing: 10) {
                        Image(systemName: systemImage)
                            .font(.largeTitle)
                            .padding(.top)
                            .foregroundStyle(.black)
                        Text(title)
                            .font(.title)
                            .foregroundStyle(.black)
                        
                        Text(bodyLabel)
                            .foregroundStyle(.secondary)
                            .foregroundStyle(.black)
                            .padding(.horizontal)
                            .multilineTextAlignment(.center)
                        
                        Button(action: buttonAction) {
                            Text(buttonLabel)
                                .frame(maxWidth: .infinity, minHeight: 40, maxHeight: 40)
                                .background(.white, in: .rect(cornerRadius: 10))
                                .foregroundStyle(Color.accentColor)
                                .fontWeight(.bold)
                        }
                        .padding()
                    }
                    .minimumScaleFactor(0.6)
                }
                .shadow(radius: 1)
        }
    }
}

#Preview {
    GradientHomeItemView(title: "Demo", systemImage: "play", bodyLabel: "Bla bla bla bla bla", buttonLabel: "Start", buttonAction: {})
    HomeItemView(title: "Start Demo", systemImage: "play", bodyLabel: "Bla bla bla bla bla", buttonLabel: "Start", buttonAction: {})
}

private func animatedColors(for date: Date) -> [Color] {
  let phase = CGFloat(date.timeIntervalSince1970)

  return myColors.enumerated().map { index, color in
    let hueShift = cos(phase + Double(index) * 0.3) * 0.1
    return shiftHue(of: color, by: hueShift)
  }
}

private let points: [SIMD2<Float>] = [
  SIMD2<Float>(0.0, 0.0), SIMD2<Float>(0.5, 0.0), SIMD2<Float>(1.0, 0.0),
  SIMD2<Float>(0.0, 0.5), SIMD2<Float>(0.5, 0.5), SIMD2<Float>(1.0, 0.5),
  SIMD2<Float>(0.0, 1.0), SIMD2<Float>(0.5, 1.0), SIMD2<Float>(1.0, 1.0)
]

private let myColors: [Color] = [
    Color(hex: "#FFEAFF"),Color(hex: "#FFFFFF"),Color(hex: "#FFCFFF"),
Color(hex: "#FFFFFF"),Color(hex: "#FBEEFF"),Color(hex: "#FFCFFF"),
Color(hex: "#FFFFF"),Color(hex: "#FFB3E2"),Color(hex: "#FFCFFF")
     ]

private func shiftHue(of color: Color, by amount: Double) -> Color {
  var hue: CGFloat = 0
  var saturation: CGFloat = 0
  var brightness: CGFloat = 0
  var alpha: CGFloat = 0

  UIColor(color).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

  hue += CGFloat(amount)
  hue = hue.truncatingRemainder(dividingBy: 1.0)

  if hue < 0 {
    hue += 1
  }

  return Color(hue: Double(hue), saturation: Double(saturation), brightness: Double(brightness), opacity: Double(alpha))
}
