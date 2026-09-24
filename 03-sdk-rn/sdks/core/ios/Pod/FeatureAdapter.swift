import UIKit

/// What every feature adapter shares: the React module it renders, how its parameters become
/// properties, and the parameters it pushed last. A feature adds its module name, its
/// field-by-field marshalling and, if it reports back, the handler for its results.
@MainActor
open class FeatureAdapter<Params: Equatable> {
    private let moduleName: String
    private let properties: (Params) -> [String: Any]
    private var lastPushed: Params?
    /// The runtime keeps one surface per module, so a screen shown again would still hold the
    /// state of the last showing; React keys the screen on this number and starts it afresh.
    private var presentation = 0

    public init(moduleName: String, properties: @escaping (Params) -> [String: Any]) {
        self.moduleName = moduleName
        self.properties = properties
    }

    public func makeViewController(params: Params) -> UIViewController {
        lastPushed = params
        presentation += 1
        return FightDeckRuntime.shared.makeViewController(moduleName: moduleName, properties: pushed(params))
    }

    /// Only a change reaches React: new properties re-render the surface from its root.
    public func update(params: Params) {
        guard params != lastPushed else { return }
        lastPushed = params
        FightDeckRuntime.shared.updateProperties(moduleName: moduleName, properties: pushed(params))
    }

    private func pushed(_ params: Params) -> [String: Any] {
        properties(params).merging(["presentation": presentation]) { _, token in token }
    }
}
