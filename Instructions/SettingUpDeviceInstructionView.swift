import SwiftUI

struct SettingUpDeviceInstructionView: View {
    @Binding var isShowGuidesView: Bool
    @State private var navigateToNext = false
    var body: some View {
            VStack {
                Spacer()
                Text("Setting up the device")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                
                HStack {
                    Image(systemName: "ipad.gen2.landscape")
                    
                    Image(systemName: "iphone.gen3.landscape")
                }
                .font(.system(size: 144))
                
                Group {
                    Text("- Use tripod or another technique to stabilize the camera.")
                    
                    Text("- Use your device in landscape mode.")
                }
                .font(.largeTitle)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                //         .fontWeight(.medium)
                .padding(.top)
                
                
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
                SettingUpAngleInstructionsView(isShowGuidesView: $isShowGuidesView)
            }
        
    }
}

#Preview {
    SettingUpDeviceInstructionView(isShowGuidesView: .constant(false))
}
