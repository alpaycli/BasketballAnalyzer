import SwiftUI

struct SettingUpHoopInstructionView: View {
    @Binding var isShowGuidesView: Bool
    
    @State private var selectedTabIndex = 0
    var body: some View {
        VStack {
            Spacer()
            Text("Setting up the hoop")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.vertical)
            Spacer()
            
            TabView(selection: $selectedTabIndex) {
                itemView("wrongHoopSetup1", "correctHoopSetup1")
                    .padding(.horizontal)
                    .tag(0)
                itemView("wrongHoopSetup2", "correctHoopSetup2")
                    .padding(.horizontal)
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .containerRelativeFrame(.horizontal) { length, _ in
                length - 60
            }
//            .background(Color.red)
            
            
            Spacer()
            SmallButton("Continue") {
                if selectedTabIndex == 0 {
                    withAnimation {
                        selectedTabIndex = 1
                    }
                } else {
                    isShowGuidesView = false
                }
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

extension SettingUpHoopInstructionView {
    private func itemView(_ wrongImage: String, _ correctImage: String) -> some View {
        HStack(spacing: 20) {
            VStack {
                Image(systemName: "xmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.red.gradient)
                Image(wrongImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: 5))
            }
            
            VStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.green.gradient)
                Image(correctImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: 5))
            }
        }
    }
}
