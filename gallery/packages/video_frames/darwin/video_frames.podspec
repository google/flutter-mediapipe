# The gallery builds with Swift Package Manager (video_frames/Package.swift);
# this spec serves an app that still uses CocoaPods. Nothing in CI uses it.
Pod::Spec.new do |s|
  s.name             = 'video_frames'
  s.version          = '0.1.0'
  s.summary          = 'Decodes a video file frame by frame with AVFoundation.'
  s.homepage         = 'https://github.com/google/flutter-mediapipe'
  s.license          = { :type => 'Apache-2.0' }
  s.author           = { 'mediapipe_flutter' => 'https://github.com/google/flutter-mediapipe' }
  s.source           = { :path => '.' }
  s.source_files     = 'video_frames/Sources/video_frames/**/*'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '15.0'
  s.osx.deployment_target = '14.0'
  s.swift_version = '5.0'
end
