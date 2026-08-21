require 'json'

package = JSON.parse(File.read(File.join(__dir__, '..', 'package.json')))

Pod::Spec.new do |s|
  s.name         = 'BetslipSDK'
  s.version      = package['version']
  s.summary      = 'FightDeck bet slip feature SDK'
  s.homepage     = 'https://github.com/fightdeck/fightdeck'
  s.license      = { type: 'MIT' }
  s.author       = 'FightDeck'
  s.platforms    = { ios: '26.0' }
  s.source       = { git: 'https://github.com/fightdeck/fightdeck.git', tag: s.version.to_s }

  s.source_files = 'Pod/**/*.{swift}'
  s.swift_version = '6.0'
  s.dependency 'FightDeckRNRuntime'
end
