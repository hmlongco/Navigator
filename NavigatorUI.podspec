Pod::Spec.new do |s|
  s.name             = 'NavigatorUI'
  s.version          = '2.0.2'
  s.summary          = 'Advanced navigation support for SwiftUI based on NavigationStack'
  
  s.description      = <<-DESC
  Navigator provides SwiftUI with a simple yet powerful navigation layer based on NavigationStack.
  Supports deep linking, checkpoints, modular app patterns, coordination, and eliminates
  the need for manual navigationDestination registrations.
  DESC
  
  s.homepage         = 'https://github.com/hmlongco/Navigator'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = "Michael Long"
  s.source           = { :git => 'https://github.com/hmlongco/Navigator.git', :tag => s.version.to_s }
  
  s.swift_version    = '5.10'
  s.platforms        = {
    :ios => '17.0',
    :osx => '14.0',
    :tvos => '17.0',
    :watchos => '10.0',
    :visionos => '1.0'
  }
  
  s.source_files     = 'Sources/NavigatorUI/NavigatorUI/**/*.swift'
  s.resource_bundles = { 'NavigatorUI_Privacy' => ['Sources/NavigatorUI/PrivacyInfo.xcprivacy'] }
  s.frameworks       = 'SwiftUI', 'Combine', 'Foundation'
  
end
