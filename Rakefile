require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << 'test'
end

desc "Run tests"
task :default => :test

task :buildinstall  do
  sh 'gem build ./spaceape-cfn.gemspec'
  sh 'gem install spaceape-cfn-*.gem --no-rdoc --no-ri'
  sh 'rm spaceape-cfn-*.gem'
  sh 'rbenv rehash'
end
