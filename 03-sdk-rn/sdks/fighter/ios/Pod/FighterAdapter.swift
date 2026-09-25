import FightDeckRNRuntime

/// The fighter profile reports nothing back, so the shared adapter already is its hosting.
public final class FighterAdapter: FeatureAdapter<FighterParams>, FighterHosting {
    public init() {
        super.init(moduleName: "FighterFeature") { params in
            [
                "fighterJSON": params.fighterJSON,
                "portraitURL": params.portraitURL,
            ]
        }
    }
}
