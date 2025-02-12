import SwiftUI

struct SettingUpHoopInstructionView: View {
    @Binding var isShowGuidesView: Bool
    var body: some View {
        VStack {
            Spacer()
            Text("Setting up the hoop")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.vertical)
            Spacer()
            
            HStack(spacing: 60) {
                VStack(spacing: 20) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.red.gradient)
                    
                    Image("wrongHoopSetup1")
                        .resizable()
                        .scaledToFit()
                        .clipShape(.rect(cornerRadius: 5))
                    
                    Image("wrongHoopSetup2")
                        .resizable()
                        .scaledToFit()
                        .clipShape(.rect(cornerRadius: 5))

                }
                
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.green.gradient)
                    
                    Image("correctHoopSetup1")
                        .resizable()
                        .scaledToFit()
                        .clipShape(.rect(cornerRadius: 5))
                    
                    Image("correctHoopSetup2")
                        .resizable()
                        .scaledToFit()
                        .clipShape(.rect(cornerRadius: 5))
                }
            }
            
            Spacer()
            SmallButton("Continue") {
                isShowGuidesView = false
            }
            .backgroundStyle(.blue)
            .foregroundStyle(.white)
            .fontWeight(.bold)
            Spacer()
        }
    }
}

#Preview {
    SettingUpHoopInstructionView(isShowGuidesView: .constant(false))
}
