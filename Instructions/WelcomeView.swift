import SwiftUI

struct WelcomeView: View {
    @Binding var isShow: Bool
    @State private var navigateToNext = false
    
    @State private var moveFrom = false
    @State private var showPortraitAlert = false
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
                .disabled(showPortraitAlert)
                Spacer()
                
            }
            .navigationDestination(isPresented: $navigateToNext) {
                SettingUpDeviceInstructionView(isShowGuidesView: $isShow)
            }
            .onAppear {
                guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
                withAnimation {
                    showPortraitAlert = scene.interfaceOrientation.isPortrait
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
                withAnimation {
                    showPortraitAlert = scene.interfaceOrientation.isPortrait
                }
            }
            .overlay {
                if showPortraitAlert {
                    portraitAlertView
                }
            }
        }
    }
    private var portraitAlertView: some View {
        VStack {
            Image(systemName: "rectangle.landscape.rotate")
                .font(.system(size: 80))
                .padding()
                .symbolEffect(.breathe)
            Text("Rotate Device to Landscape")
                .font(.title)
        }
        .fontWeight(.bold)
        .frame(width: 300, height: 300, alignment: .center)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 25, style: .continuous))
        .shadow(radius: 15)
    }
}

#Preview {
    WelcomeView(isShow: .constant(true))
}
