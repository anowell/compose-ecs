require 'rake/testtask'

task default: :test

task :test do
  sh 'bundle exec rspec'
end

task :install do
  sh 'gem build ./compose-ecs.gemspec'
  sh 'gem install compose-ecs-*.gem --no-rdoc --no-ri'
  sh 'rm compose-ecs-*.gem'
  sh 'rbenv rehash'
end

task :release do
  sh 'gem release'
end
