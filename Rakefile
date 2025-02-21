# frozen_string_literal: true

# MIT License
#
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'rubygems'
require 'rake'
require 'rake/clean'

task default: %i[clean test judges rubocop]

require 'rake/testtask'
desc 'Run all unit tests'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = ['test/**/test_*.rb', 'test/**/test-*.rb']
  test.warning = true
  test.verbose = false
end

desc 'Test all judges'
task :judges do
  live = ARGV.include?('--live') ? '' : '--disable live'
  sh "judges --verbose test #{live} --no-log --lib lib --option=judges_action_version=0.0.0 judges"
end

require 'rubocop/rake_task'
desc 'Run RuboCop on all directories'
RuboCop::RakeTask.new(:rubocop) do |task|
  task.fail_on_error = true
end
