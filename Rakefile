# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'os'
require 'qbash'
require 'rubygems'
require 'rake'
require 'rake/clean'
require 'shellwords'

ENV['RACK_RUN'] = 'true'

task default: %i[clean test judges rubocop picks]

require 'rake/testtask'
desc 'Run all unit tests'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = ['test/**/test_*.rb', 'test/**/test-*.rb']
  test.warning = true
  test.verbose = false
end

desc 'Run them via Ruby, one by one'
task :picks do
  next if OS.windows?
  %w[test lib].each do |d|
    Dir["#{d}/**/*.rb"].each do |f|
      qbash("bundle exec ruby #{Shellwords.escape(f)} -- --no-cov", log: $stdout)
    end
  end
end

desc 'Test all judges'
task :judges do
  live = ARGV.include?('--live') ? '' : '--disable live'
  sh "judges --verbose test #{live} --no-log --lib lib --option=action_version=0.0.0 judges"
end

require 'rubocop/rake_task'
desc 'Run RuboCop on all directories'
RuboCop::RakeTask.new(:rubocop) do |task|
  task.fail_on_error = true
end
