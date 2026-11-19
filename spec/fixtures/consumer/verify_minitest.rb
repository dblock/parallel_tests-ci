# frozen_string_literal: true

require_relative 'support'

package = Consumer.installed_package
Consumer.in_temporary_directory do
  FileUtils.cp_r(File.expand_path('../minitest', __dir__), 'test')
  minitest_run = ParallelTests::CI::Run.prepare(directory: 'minitest-plan', framework: 'minitest', shards: 1,
                                                test_options: ['--name', '/test_first|no match/'])
  env = { 'PTCI_OBSERVED' => File.expand_path('minitest-observed.txt') }
  unless minitest_run.run(shard: 1, attempt: 1, directory: 'minitest-results/1', env: env).zero?
    abort 'Installed Minitest shard failed'
  end
  minitest_timings = minitest_run.collect(directory: 'minitest-results', output: 'minitest-baseline.log')
  observed = File.readlines('minitest-observed.txt', chomp: true)
  unless observed == ['first'] && minitest_timings.key?('test/first_test.rb')
    abort "Installed Minitest shard produced #{observed.inspect} and #{minitest_timings.keys.inspect}"
  end

  File.write('Gemfile', <<~GEMFILE)
    source 'https://rubygems.org'
    gem 'minitest', '~> 5.27', require: false
    gem 'parallel_tests-ci', '#{package.version}', require: 'parallel_tests/ci/minitest'
  GEMFILE
  boot = 'require "bundler"; Bundler.require'
  [nil, ''].each do |value|
    unless system({ 'PTCI_RUNTIME_LOG' => value }, Gem.ruby, '-e', "#{boot}; abort if defined?(Minitest)")
      abort 'Gemfile require loaded Minitest without a timing output path'
    end
  end
  File.write('timed_test.rb', <<~RUBY)
    class Example < Minitest::Test
      def test_timing
        assert true
      end
    end
  RUBY
  timed_run = "#{boot}; require_relative 'timed_test'; exit Minitest.run"
  unless system({ 'PTCI_RUNTIME_LOG' => 'minitest.log' }, Gem.ruby, '-e', timed_run) &&
         ParallelTests::CI::RuntimeLog.read('minitest.log').keys == ['timed_test.rb']
    abort 'Gemfile require did not record Minitest timings'
  end

  File.write('Gemfile', <<~GEMFILE)
    source 'https://rubygems.org'
    gem 'minitest', '~> 5.27'
    gem 'parallel_tests-ci', '#{package.version}'
  GEMFILE
  unless system({ 'PTCI_RUNTIME_LOG' => 'detected.log' }, Gem.ruby, '-e', timed_run) &&
         ParallelTests::CI::RuntimeLog.read('detected.log').keys == ['timed_test.rb']
    abort 'Default Gemfile require did not detect Minitest and record timings'
  end
end

puts 'Installed Minitest consumer passed.'
