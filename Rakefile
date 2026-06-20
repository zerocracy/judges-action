# frozen_string_literal: true

require 'rake/testtask'

ENV['RAKE_RUN'] = 'true'

task default: :test

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.test_files = FileList['test/**/test__*.rb']
  t.verbose = true
end