import UIKit

/// What every feature adapter shares: the React module it renders, how its parameters become
/// properties, and the parameters it pushed last. A feature adds its module name, its
/// field-by-field marshalling and, if it reports back, the handler for its results.
@MainActor
open class FeatureAdapter<Params: Equatable> {
    private let moduleName: String
    private let properties: (Params) -> [String: Any]
    private var lastPushed: Params?
    /// The surface on screen now. Each showing gets its own, so the last one made is the one a
    /// parameter update is for.
    private weak var controller: UIViewController?

    public init(moduleName: String, properties: @escaping (Params) -> [String: Any]) {
        self.moduleName = moduleName
        self.properties = properties
    }

    public func makeViewController(params: Params) -> UIViewController {
        lastPushed = params
        let controller = FightDeckRuntime.shared.makeViewController(moduleName: moduleName, properties: properties(params))
        self.controller = controller
        return controller
    }

    /// Only a change reaches React: new properties re-render the surface from its root.
    public func update(params: Params) {
        guard params != lastPushed, let controller else { return }
        lastPushed = params
        FightDeckRuntime.shared.updateProperties(properties(params), for: controller)
    }
}
