# frozen_string_literal: true

require_relative 'support'
require 'open3'

package = Consumer.installed_package
consumer_env = { 'PTCI_CONSUMER_VERSION' => package.version.to_s }
Consumer.in_temporary_directory do
  unless system(Gem.ruby, '-r', 'rspec', '-r', 'parallel_tests-ci', '-e', '')
    abort 'Default require did not accept RSpec'
  end

  boot = 'require "bundler"; Bundler.require'
  FileUtils.cp(File.expand_path('minitest_default/Gemfile', __dir__), 'Gemfile')
  FileUtils.cp(File.expand_path('minitest_explicit/timed_test.rb', __dir__), 'timed_test.rb')
  timed_run = "#{boot}; require_relative 'timed_test'; exit Minitest.run"
  unless system(consumer_env.merge('PTCI_RUNTIME_LOG' => 'detected.log'), Gem.ruby, '-e', timed_run) &&
         ParallelTests::CI::RuntimeLog.read('detected.log').keys == ['timed_test.rb']
    abort 'Default Gemfile require did not detect Minitest and record timings'
  end

  FileUtils.cp(File.expand_path('rspec_explicit/Gemfile', __dir__), 'Gemfile')
  both_loaded = 'abort unless defined?(RSpec) && defined?(Minitest)'
  no_minitest_hook = "#{boot}; #{both_loaded}; abort if defined?(ParallelTests::Test::RuntimeLogger)"
  env = consumer_env.merge('PTCI_RUNTIME_LOG' => 'unused.log')
  abort 'Explicit RSpec require failed with both frameworks loaded' unless system(env, Gem.ruby, '-e', no_minitest_hook)

  FileUtils.cp(File.expand_path('minitest_both/Gemfile', __dir__), 'Gemfile')
  timed_both = "#{boot}; #{both_loaded}; require_relative 'timed_test'; exit Minitest.run"
  unless system(consumer_env.merge('PTCI_RUNTIME_LOG' => 'both.log'), Gem.ruby, '-e', timed_both) &&
         ParallelTests::CI::RuntimeLog.read('both.log').keys == ['timed_test.rb']
    abort 'Explicit Minitest require failed with both frameworks loaded'
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
