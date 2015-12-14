Gem::Specification.new do |s|
  s.name        = 'compose-ecs'
  s.version     = '0.0.1'
  s.date        = '2015-12-07'
  s.summary     = "A bridge between docker-compose and AWS ECS Task Definitions"
  s.description = "A bridge between docker-compose and AWS ECS Task Definitions"
  s.authors     = ["Josh McGhee"]
  s.email       = 'joshua@spaceapegames.com'
  s.files       = ["lib/compose-ecs.rb", "bin/compose-ecs"]
  s.homepage    =
    'http://rubygems.org/gems/ecs-compose'
  s.license       = 'MIT'

  s.add_runtime_dependency 'json'
  s.add_runtime_dependency 'yaml'
end
