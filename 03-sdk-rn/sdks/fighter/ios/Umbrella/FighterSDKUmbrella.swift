// SPM binary targets cannot declare dependencies on other packages. The thin source
// target above re-exports the binary so consumers write `import FighterSDK`.
@_exported import FighterSDKBinary
