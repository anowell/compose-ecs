require 'rake/testtask'

task :default => :test

task :test do
  sh 'bundle exec rspec'
end

task :buildinstall  do
  sh 'gem build ./compose-ecs.gemspec'
  sh 'gem install compose-ecs-*.gem --no-rdoc --no-ri'
  sh 'rm compose-ecs-*.gem'
  sh 'rbenv rehash'
end
