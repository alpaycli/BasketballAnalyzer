//
//  SwiftUIView.swift
//  BasketballAnalyzer
//
//  Created by Alpay Calalli on 05.02.25.
//

import SwiftUI

struct InstructionsView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                Text("Angle Instruction")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                HStack(alignment: .top) {
                    VStack {
                        Text("❌")
                            .font(.largeTitle)
                        
                        VStack(alignment: .leading) {
                            Image("prefferedAngle1")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 500)
                                .clipShape(.rect(cornerRadius: 5))
                                .redacted(reason: .placeholder)
                            
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
                        Text("✅")
                            .font(.largeTitle)
                        
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
                Button("Continue") {}
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.bottom)
                    .fontWeight(.bold)
                
            }
        }
    }
}

#Preview {
    InstructionsView()
}
