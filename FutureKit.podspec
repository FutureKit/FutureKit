Pod::Spec.new do |s|
  s.name = 'FutureKit'
  s.version = '0.8.7'
  s.license = 'MIT'
  s.summary = 'A Swift based Future/Promises Library for IOS and OS X.'
  s.homepage = 'https://github.com/FutureKit/FutureKit'
  s.social_media_url = 'http://twitter.com/swiftfuturekit'
  s.authors = { 'Michael Gray' => 'michael@futurekit.org' }
  s.source = { :git => 'https://github.com/FutureKit/FutureKit.git', :tag => s.version }

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.9'

  s.source_files = "FutureKit/*.swift", "FutureKit/**/*.swift"
  
  s.requires_arc = true
end
