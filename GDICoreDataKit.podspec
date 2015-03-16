#
# Be sure to run `pod lib lint GDICoreDataKit.podspec' to ensure this is a
# valid spec and remove all comments before submitting the spec.
#
# Any lines starting with a # are optional, but encouraged
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "GDICoreDataKit"
  s.version          = "0.1.0"
  s.summary          = "Tools to work with CoreData."
  s.description      = <<-DESC
                      Tools to work with CoreData.
                      More Coming soon...
                     DESC
  s.homepage         = "https://github.com/gdavis/GDICoreDataKit"
  # s.screenshots     = "www.example.com/screenshots_1", "www.example.com/screenshots_2"
  s.license          = 'MIT'
  s.author           = { "Grant Davis" => "grant.davis@gmail.com" }
  s.source           = { :git => "https://github.com/gdavis/GDICoreDataKit.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/ghunterdavis'

  s.platform     = :ios, '5.0'
  s.requires_arc = true

  s.source_files = 'Pod/Classes'
end
