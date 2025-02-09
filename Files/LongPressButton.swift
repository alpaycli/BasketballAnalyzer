//
//  LongPressButton.swift
//  BasketballAnalyzer
//
//  Created by Alpay Calalli on 16.01.25.
//

import SwiftUI

struct LongPressButton: View {
  let duration: TimeInterval
  @State private var progress: CGFloat = 0
  @State private var isDone = false
    
    @State private var isHolding = false
    
    @State private var timer = Timer.publish(every: 0.01, on: .current, in: .common).autoconnect()
    @State private var timerCount: CGFloat = 0
    
    @State private var showText = false
    
    let action: () -> ()

  var body: some View {
      VStack(spacing: 0) {
              Text("Hold to Finish")
                  .foregroundStyle(.white)
                  .fontDesign(.serif)
                  .transition(.opacity)
                  .opacity(showText ? 1 : 0)
          Label("Finish", systemImage: "stop.circle")
              .padding(.horizontal, 20)
              .padding(.vertical, 10)
              .foregroundStyle(.white)
              .fontWeight(.bold)
              .font(.headline.smallCaps())
              .background {
                  ZStack(alignment: .leading) {
                      Rectangle()
                          .fill(.red.gradient)
                      
                      GeometryReader { geo in
                          if !isDone {
                              Rectangle()
                                  .fill(.red.mix(with: .gray, by: 0.25))
                                  .frame(width: geo.size.width * progress)
                                  .transition(.opacity)
                          }
                      }
                  }
              }
              .clipShape(.rect(cornerRadius: 10))
              .onLongPressGesture(minimumDuration: duration, perform: {
                  isHolding = false
                  cancelTimer()
                  withAnimation(.easeInOut(duration: 0.2)) {
                      isDone = true
                      action()
                  }
              }, onPressingChanged: { status in
                  if status {
                      print("here");
                      withAnimation(.easeInOut(duration: 0.05)) {
                          showText = true
                      }
                      isDone = false
                      reset()
                      isHolding = true
                      startTimer()
                  } else {
                      print("Here2")
                      withAnimation(.easeInOut(duration: 2)) {
                          showText = false
                      }
                  }
              })
              .simultaneousGesture(dragGesture)
              .onReceive(timer) { _ in
                  if isHolding && progress != 1 {
                      timerCount += 0.01
                      progress = max(min(timerCount / duration, 1), 0)
                  }
              }
              .onAppear(perform: cancelTimer)
              .sensoryFeedback(.impact(weight: .light), trigger: timerCount)
              .sensoryFeedback(.success, trigger: isDone)
      }
      
      
    
  }
    func startTimer() {
        timer = Timer.publish(every: 0.01, on: .current, in: .common).autoconnect()
    }
    
    func cancelTimer() {
        timer.upstream.connect().cancel()
    }
    
    func reset() {
        isHolding = false
        progress = 0
        timerCount = 0
    }
    
    var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onEnded { _ in
                print("before")
                guard !isDone else { return }
                print("after")
                cancelTimer()
                withAnimation(.snappy) {
                    reset()
                }
            }
    }
}
