//
//  SwiftUIView.swift
//  BasketballAnalyzer
//
//  Created by Alpay Calalli on 05.02.25.
//

import SwiftUI

struct SettingUpAngleInstructionsView: View {
    @Binding var isShowGuidesView: Bool
    @State private var navigateToNext = false
    var body: some View {
            VStack {
                Spacer()
                Text("Angle Instruction")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                HStack(alignment: .top) {
                    VStack {
                        Image(systemName: "xmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.red.gradient)
                        
                        VStack(alignment: .leading) {
                            Image("unprefferedAngle1")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 500)
                                .clipShape(.rect(cornerRadius: 5))
//                                .redacted(reason: .placeholder)
                            
                            Text("Bad Practices :")
                                .font(.headline)
                                .foregroundStyle(.red)
                            
                            Text("""
                            - Noisy venue.
                            - Player and Hoop hardly visible.
                            - Ball's movement hardly visible.
                            - Many people in frame.
                            """)
                            .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.green.gradient)
                        
                        VStack(alignment: .leading) {
                            Image("prefferedAngle1")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 500)
                                .clipShape(.rect(cornerRadius: 5))
                            
                            Text("Good Practices :")
                                .font(.headline)
                                .foregroundStyle(.green)
                            
                            Text("""
                            - Clean venue.
                            - Player and Hoop clearly visible.
                            - Ball's movement clearly visible.
                            - Max. 2 people in frame.
                            """)
                            .foregroundStyle(.secondary)
                        }
                        
                    }
                }
                .padding(.horizontal, 40)
                
                Spacer()
                SmallButton("Next", systemImage: "arrow.right") {
                    navigateToNext = true
                }
                .backgroundStyle(.blue)
                .foregroundStyle(.white)
                .fontWeight(.bold)
                Spacer()
                
            }
            .navigationDestination(isPresented: $navigateToNext) { 
                SettingUpHoopInstructionView(isShowGuidesView: $isShowGuidesView)
            }
        
    }
}

#Preview {
    SettingUpAngleInstructionsView(isShowGuidesView: .constant(false))
}
