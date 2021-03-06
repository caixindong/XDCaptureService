#
# Be sure to run `pod lib lint XDCaptureService.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'XDCaptureService'
  s.version          = '1.2.0'
  s.summary          = 'A short description of XDCaptureService.'
  s.homepage         = 'https://github.com/caixindong/XDCaptureService'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { '458770054@qq.com' => '458770054@qq.com' }
  s.source           = { :git => 'https://github.com/caixindong/XDCaptureService.git', :tag => s.version.to_s }

  s.ios.deployment_target = '8.0'

  s.source_files = 'XDCaptureService/Classes/**/*'

  s.public_header_files = 'XDCaptureService/Classes/XDCaptureService.h'
  
  s.frameworks = 'AVFoundation', 'CoreImage'
end
