@_implementationOnly import React

final class FightDeckGlassChipRowContainer: UIView {
    @objc var values: [String] = [] {
        didSet { hostView?.values = values }
    }

    @objc var accentHex: String = "#E8B33C" {
        didSet { hostView?.accentHex = accentHex }
    }

    @objc var onSelect: RCTDirectEventBlock?

    private var hostView: FightDeckGlassChipRowHostView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        let host = FightDeckGlassChipRowHostView(frame: .zero)
        host.onSelect = { [weak self] value in
            self?.onSelect?(["value": value])
        }
        host.translatesAutoresizingMaskIntoConstraints = false
        addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: leadingAnchor),
            host.trailingAnchor.constraint(equalTo: trailingAnchor),
            host.topAnchor.constraint(equalTo: topAnchor),
            host.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        hostView = host
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
}

@objc(FightDeckGlassChipRowViewManager)
final class FightDeckGlassChipRowViewManager: RCTViewManager {
    override static func requiresMainQueueSetup() -> Bool { true }

    override func view() -> UIView! {
        FightDeckGlassChipRowContainer()
    }
}
