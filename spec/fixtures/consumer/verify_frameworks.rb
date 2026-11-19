# frozen_string_literal: true

require_relative 'support'
require 'open3'

package = Consumer.installed_package
Consumer.in_temporary_directory do
  unless system(Gem.ruby, '-r', 'rspec', '-r', 'parallel_tests-ci', '-e', '')
    abort 'Default require did not accept RSpec'
  end

  FileUtils.cp(File.expand_path('framework_explicit/Gemfile', __dir__), 'Gemfile')
  boot = 'require "bundler"; Bundler.require'
  no_minitest_hook = "#{boot}; abort if defined?(ParallelTests::Test::RuntimeLogger)"
  env = { 'PTCI_RUNTIME_LOG' => 'unused.log', 'PTCI_CONSUMER_VERSION' => package.version.to_s }
  abort 'Explicit RSpec require failed with both frameworks loaded' unless system(env, Gem.ruby, '-e', no_minitest_hook)

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
