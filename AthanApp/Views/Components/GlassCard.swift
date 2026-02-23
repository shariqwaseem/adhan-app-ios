import SwiftUI

struct GlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }
}

extension View {
    func glassCard() -> some View {
        modifier(GlassCardModifier())
    }
}
