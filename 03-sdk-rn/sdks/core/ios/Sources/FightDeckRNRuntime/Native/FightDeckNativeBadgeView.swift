import SwiftUI

/// SwiftUI content embedded inside the Fabric badge. The Fabric component itself
/// cannot be pure Swift — see `FightDeckNativeBadgeComponentView.mm`.
struct FightDeckNativeBadgeView: View {
    let label: String
    let accent: Bool

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(accent ? Color(red: 0.91, green: 0.70, blue: 0.24) : Color(red: 0.11, green: 0.13, blue: 0.18))
            .foregroundStyle(accent ? Color(red: 0.04, green: 0.05, blue: 0.08) : Color(red: 0.60, green: 0.65, blue: 0.72))
            .clipShape(Capsule())
    }
}
