import SwiftUI
import UIKit

@MainActor
@Observable
final class FightDeckGlassChipRowModel {
    var values: [String] = []
    var accentHex: String = "#E8B33C"
    var onSelect: ((String) -> Void)?
}

@MainActor
final class FightDeckGlassChipRowHostView: UIView {
    private let model = FightDeckGlassChipRowModel()
    private let hostingController: UIHostingController<FightDeckGlassChipRowView>

    var values: [String] = [] {
        didSet { model.values = values }
    }

    var accentHex: String = "#E8B33C" {
        didSet { model.accentHex = accentHex }
    }

    var onSelect: ((String) -> Void)? {
        didSet { model.onSelect = onSelect }
    }

    override init(frame: CGRect) {
        hostingController = UIHostingController(rootView: FightDeckGlassChipRowView(model: model))
        super.init(frame: frame)
        backgroundColor = .clear
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
}

struct FightDeckGlassChipRowView: View {
    @Bindable var model: FightDeckGlassChipRowModel

    private var accent: Color {
        Color(hex: model.accentHex) ?? Color(red: 0.91, green: 0.70, blue: 0.24)
    }

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(model.values, id: \.self) { value in
                    chipButton(value)
                }
            }
        }
    }

    @ViewBuilder
    private func chipButton(_ value: String) -> some View {
        Button {
            model.onSelect?(value)
        } label: {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accent)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}

private extension Color {
    init?(hex: String) {
        var filtered = ""
        for character in hex.lowercased() {
            let digit = String(character)
            if "0123456789abcdef".contains(digit) {
                filtered += digit
            }
        }
        guard filtered.count >= 6 else { return nil }
        let start = filtered.startIndex
        let redHex = String(filtered[start ..< filtered.index(start, offsetBy: 2)])
        let greenHex = String(filtered[filtered.index(start, offsetBy: 2) ..< filtered.index(start, offsetBy: 4)])
        let blueHex = String(filtered[filtered.index(start, offsetBy: 4) ..< filtered.index(start, offsetBy: 6)])
        guard
            let red = Int(redHex, radix: 16),
            let green = Int(greenHex, radix: 16),
            let blue = Int(blueHex, radix: 16)
        else { return nil }
        self.init(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
    }
}
