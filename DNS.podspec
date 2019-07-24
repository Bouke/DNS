Pod::Spec.new do |s|

  s.name         = "DNS"
  s.version      = "1.1.1"
  s.summary      = "A lib for parsing and serializing DNS packets."

  s.homepage     = "https://github.com/mcfedr/DNS"
  s.license      = "MIT"
  s.authors            = { "Fred Cox" => "mcfedr@gmail.com", "Bouke Haarsma" => "email@email.com"}

  s.ios.deployment_target = "9.3"
  s.osx.deployment_target = "10.10"

  s.source       = { :git => "https://github.com/mcfedr/DNS.git", :tag => "#{s.version}" }

  s.source_files  = "Sources/DNS/**/*.swift"
  s.swift_version = "4.0"
end
