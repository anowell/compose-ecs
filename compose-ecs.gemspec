require 'lib/compose-ecs/version.rb'

Gem::Specification.new do |s|
  s.name        = 'compose-ecs'
  s.version     = ComposeECS::VERSION
  s.date        = '2015-12-07'
  s.summary     = "A bridge between docker-compose and AWS ECS Task Definitions"
  s.description = "A bridge between docker-compose and AWS ECS Task Definitions"
  s.authors     = ["Josh McGhee"]
  s.email       = 'joshua@spaceapegames.com'
  s.files       = `git ls-files`.split($/)
  s.require_paths = ["lib"]
  s.homepage    = 'https://github.com/spaceapegames/compose-ecs'
  s.license       = 'MIT'

  s.add_development_dependency 'rake', '~> 10.5.0'
  s.add_development_dependency 'rspec', '~> 3.4'
  s.add_development_dependency 'gem-release', '~> 0.7.4'

  s.add_runtime_dependency 'json', '~> 1.8.3'
  s.add_runtime_dependency 'gli', '~> 2.13.2'

  s.bindir = 'bin'
  s.executables = ['compose-ecs']
end
