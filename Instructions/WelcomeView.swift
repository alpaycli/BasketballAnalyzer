import SwiftUI

struct WelcomeView: View {
    @Binding var isShow: Bool
    @State private var navigateToNext = false
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                Spacer()
                Group {
                    Text("Welcome to ")
                    +
                    Text("Splash30")
                        .fontWeight(.bold)
                }
                .font(.largeTitle)
                
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
