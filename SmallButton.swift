import SwiftUI

struct SmallButton<Label: View>: View {
    private let action: () -> Void
    private let label: Label
    
    @Environment(\.controlSize) var controlSize
    @Environment(\.backgroundStyle) private var backgroundStyle
    @Environment(\.isEnabled) var isEnabled
    
    init(
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.action = action
        self.label = label()
    }
    
    var body: some View {
        Button {
            action()
        } label: {
            label
                .frame(width: width)
                .padding(.vertical, padding)
                .background(isEnabled ?
                            backgroundStyle ?? AnyShapeStyle(Color.gray) :
                                AnyShapeStyle(Color.gray.secondary))
                .clipShape(.rect(cornerRadius: 20))
        }
    }
}

#Preview {
    SmallButton("Salam") {
        
    }
    .backgroundStyle(.purple)
    
    SmallButton {
        
    } label: {
        Text("Salam")
    }
    .backgroundStyle(.green)
}

extension SmallButton where Label == Text {
    init(
        _ titleKey: LocalizedStringKey,
        action: @escaping () -> Void
    ) {
        self.init(
            action: action,
            label: {
                Text(titleKey)
            }
        )
    }
}

extension SmallButton where Label == SwiftUI.Label<Text, Image> {
    init(
        _ titleKey: LocalizedStringKey,
        systemImage: String,
        action: @escaping () -> Void
    ) {
        self.init(
            action: action,
            label: {
                Label(titleKey, systemImage: systemImage)
            }
        )
    }
}

extension SmallButton {
    var width: CGFloat {
        switch controlSize {
        case .mini: 100
        case .small: 120
        case .large: 200
        case .regular: 180
        case .extraLarge: UIScreen.main.bounds.width / 2 - 25
        @unknown default: 100
        }
    }
    
    var padding: CGFloat {
        switch controlSize {
        case .mini: 10
        case .small: 10
        case .large: 20
        case .extraLarge, .regular: 20
        @unknown default: 20
        }
    }
}
