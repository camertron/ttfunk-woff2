$LOAD_PATH.push('./lib')

require 'rake'
require 'rspec/core/rake_task'
require 'rubygems/package_task'
require 'rubocop/rake_task'

task default: %i[rubocop spec]

desc 'Run all rspec files'
RSpec::Core::RakeTask.new('spec')

RuboCop::RakeTask.new
