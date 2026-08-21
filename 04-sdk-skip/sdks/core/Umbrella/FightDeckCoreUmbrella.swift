// SPM binary targets cannot declare dependencies on other packages. The thin source
// target above re-exports the binary so consumers write `import FightDeckCore`.
@_exported import FightDeckCoreBinary
