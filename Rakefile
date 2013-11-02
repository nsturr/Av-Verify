require 'rspec'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.fail_on_error = false
  t.rspec_opts = ['--color', '--order=default']
  t.pattern = ARGV[1] || "spec/spec_helper.rb"
end

task default: :spec
