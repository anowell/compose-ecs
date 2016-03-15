Gem::Specification.new do |s|
  s.name        = "spaceape-cfn"
  s.version     = '0.1.19'
  s.authors     = ["Louis McCormack", "Josh McGhee"]
  s.email       = "ops@spaceapegames.com"
  s.homepage    = "http://www.spaceapegames.com"
  s.summary     = "Spaceape Cloudformation Tooling"
  s.description = "Tools to help us Cloudform"
  s.required_rubygems_version = ">= 1.3.6"

  s.files         = `git ls-files`.split($/)
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ["lib"]

  s.add_development_dependency "bundler", "~> 1.3"
  s.add_development_dependency "rake"
  s.add_development_dependency "rspec"

  s.add_dependency 'cfndsl', '>= 0.1.11'
  s.add_dependency 'spaceape-lib', '>= 0.4.10'
  s.add_dependency 'compose-ecs', '>= 0.0.9'
end
