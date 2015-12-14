require 'rake/testtask'

Rake::TestTask.new do |t|
	  t.libs << 'test'
end

desc "Run tests"
task :default => :test

task :buildinstall  do
  sh 'gem build ./compose-ecs.gemspec'
  sh 'gem install compose-ecs-*.gem --no-rdoc --no-ri'
  sh 'rm compose-ecs-*.gem'
  sh 'rbenv rehash'
end
