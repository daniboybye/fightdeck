import UIKit

@MainActor
@objcMembers
final class RNHostEngineObjC: NSObject {
    static func initializeHost() {
        RNHostEngineImpl.shared.start()
    }

    static func makeSurface(moduleName: String, initialProperties: [String: Any]) -> UIViewController {
        RNHostEngineImpl.shared.makeSurface(moduleName: moduleName, properties: initialProperties)
    }

    static func destroySurface(name: String) {
        RNHostEngineImpl.shared.destroySurface(name: name)
    }

    static func updateProperties(_ properties: [String: Any], forModuleName moduleName: String) {
        RNHostEngineImpl.shared.updateProperties(properties, forModuleName: moduleName)
    }
}

@MainActor
final class RNHostEngineImpl {
    static let shared = RNHostEngineImpl()

    private var surfaces: [String: UIViewController] = [:]

    func start() {
        BundleResourceLoader.ensureBundleExtracted()
    }

    func makeSurface(moduleName: String, properties: [String: Any]) -> UIViewController {
        if let existing = surfaces[moduleName] {
            return existing
        }
        let controller = RNSurfaceViewController(moduleName: moduleName, properties: properties)
        surfaces[moduleName] = controller
        return controller
    }

    func destroySurface(name: String) {
        surfaces.removeValue(forKey: name)
    }

    func updateProperties(_ properties: [String: Any], forModuleName moduleName: String) {
        _ = properties
        _ = moduleName
    }
}

final class RNSurfaceViewController: UIViewController {
    init(moduleName: String, properties: [String: Any]) {
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = UIColor(red: 0.043, green: 0.055, blue: 0.078, alpha: 1)
        let label = UILabel()
        label.text = "RN surface: \(moduleName)"
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        _ = properties
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

enum BundleResourceLoader {
    static func ensureBundleExtracted() {
        _ = Bundle(for: RNHostEngineImpl.self).path(forResource: "fightdeck", ofType: "hbc")
    }
}
