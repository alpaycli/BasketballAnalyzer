import SwiftUI

struct WelcomeView: View {
    @Binding var isShow: Bool
    @State private var navigateToNext = false
    
    @State private var moveFrom = false 
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                Spacer()
                
                let title = Text("Splash30")
                    .foregroundStyle(Color.accentColor)
                    .fontWeight(.bold)
                    .customAttribute(HighlightingEffectAttribute())
                
                Text("Welcome to \(title)")
                    .font(.largeTitle)
                    .textRenderer(HighlightingEffectRenderer(animationProgress: moveFrom ? 3 : -1))
                    .onAppear {
                        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                            moveFrom.toggle()
                        }
                    }
                
                Text("Your basketball shooting feedback asistant.")
                    .font(.title)
                    .padding(.vertical)
                
                   Image("appPreviewWithTrajectory")
                    .resizable()
                    .scaledToFit()
                    .padding(.vertical)
                    .frame(width: 600)
                
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
                SettingUpDeviceInstructionView(isShowGuidesView: $isShow)
            }
        }
    }
}

#Preview {
    WelcomeView(isShow: .constant(true))
}
