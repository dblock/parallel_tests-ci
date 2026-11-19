# frozen_string_literal: true

require_relative 'support'
require 'open3'

package = Consumer.installed_package
Consumer.in_temporary_directory do
  unless system(Gem.ruby, '-r', 'rspec', '-r', 'parallel_tests-ci', '-e', '')
    abort 'Default require did not accept RSpec'
  end

  File.write('Gemfile', <<~GEMFILE)
    source 'https://rubygems.org'
    gem 'rspec'
    gem 'minitest', '~> 5.27'
    gem 'parallel_tests-ci', '#{package.version}', require: 'parallel_tests/ci/rspec'
  GEMFILE
  boot = 'require "bundler"; Bundler.require'
  no_minitest_hook = "#{boot}; abort if defined?(ParallelTests::Test::RuntimeLogger)"
  unless system({ 'PTCI_RUNTIME_LOG' => 'unused.log' }, Gem.ruby, '-e', no_minitest_hook)
    abort 'Explicit RSpec require failed with both frameworks loaded'
  end

  {
    [] => 'Neither RSpec nor Minitest is loaded',
    %w[-r rspec -r minitest] => 'Both RSpec and Minitest are loaded'
  }.each do |requires, message|
    output, status = Open3.capture2e(Gem.ruby, *requires, '-r', 'parallel_tests-ci', '-e', '')
    next if !status.success? && output.include?(message)

    abort "Expected default require to fail: #{message}\n#{output}"
  end
end

puts 'Installed framework detection consumer passed.'
