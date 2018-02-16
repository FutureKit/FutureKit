Pod::Spec.new do |s|
  s.name = 'FutureKit'
  s.version = '3.5.0'
  s.license = 'MIT'
  s.summary = 'A Swift based Future/Promises Library for IOS and OS X.'
  s.homepage = 'https://github.com/FutureKit/FutureKit'
  s.social_media_url = 'http://twitter.com/swiftfuturekit'
  s.authors = { 'Michael Gray' => 'michael@futurekit.org' }
  s.source = { :git => 'https://github.com/FutureKit/FutureKit.git', :tag => s.version }

  s.ios.deployment_target = '8.0'
  s.tvos.deployment_target = '9.0'
  s.watchos.deployment_target = '2.0'
  s.osx.deployment_target = '10.10'

  s.source_files = "Source/FutureKit/*.swift", "Source/FutureKit/**/*.swift"
  s.requires_arc = true
end
