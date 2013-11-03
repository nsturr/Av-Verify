require 'rspec'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |t|

  t.fail_on_error = false
  t.pattern = ARGV[1] ? "spec/#{ARGV[1]}_spec.rb" : "spec/*_spec.rb"
end

task default: :spec
