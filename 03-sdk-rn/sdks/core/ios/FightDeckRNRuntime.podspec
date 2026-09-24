require 'json'

package = JSON.parse(File.read(File.join(__dir__, '..', 'package.json')))

Pod::Spec.new do |s|
  s.name         = 'FightDeckRNRuntime'
  s.version      = package['version']
  s.summary      = 'Shared React Native runtime for FightDeck SDK features'
  s.homepage     = 'https://github.com/fightdeck/fightdeck'
  s.license      = { type: 'MIT' }
  s.author       = 'FightDeck'
  s.platforms    = { ios: '26.0' }
  s.source       = { git: 'https://github.com/fightdeck/fightdeck.git', tag: s.version.to_s }

  s.source_files = 'Pod/**/*.{h,m,mm,swift}'
  s.public_header_files = ['Pod/FightDeckRNHost.h', 'Pod/FightDeckRuntimeBridge.h']
  s.resource_bundles = {
    'FightDeckRNRuntime' => ['Resources/*']
  }

  s.swift_version = '6.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_STRICT_CONCURRENCY' => 'minimal',
  }

  s.dependency 'React-Core'
  s.dependency 'React-RCTAppDelegate'
  s.dependency 'ReactAppDependencyProvider'
  s.dependency 'ReactCommon/turbomodule/core'
  # What codegen compiled from `codegenConfig` in 03-sdk-rn/package.json.
  s.dependency 'ReactCodegen'
end
