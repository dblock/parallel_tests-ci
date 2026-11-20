# frozen_string_literal: true

require_relative '../../consumer/support'

package = Consumer.installed_package
consumer_env = { 'PTCI_CONSUMER_VERSION' => package.version.to_s }
Consumer.in_temporary_directory do
  FileUtils.cp_r(File.expand_path('../suite', __dir__), 'test')
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

  FileUtils.cp(File.expand_path('explicit/Gemfile', __dir__), 'Gemfile')
  boot = 'require "bundler"; Bundler.require'
  [nil, ''].each do |value|
    unless system(consumer_env.merge('PTCI_RUNTIME_LOG' => value), Gem.ruby, '-e',
                  "#{boot}; abort if defined?(Minitest)")
      abort 'Gemfile require loaded Minitest without a timing output path'
    end
  end
  FileUtils.cp(File.expand_path('explicit/timed_test.rb', __dir__), 'timed_test.rb')
  timed_run = "#{boot}; require_relative 'timed_test'; exit Minitest.run"
  unless system(consumer_env.merge('PTCI_RUNTIME_LOG' => 'minitest.log'), Gem.ruby, '-e', timed_run) &&
         ParallelTests::CI::RuntimeLog.read('minitest.log').keys == ['timed_test.rb']
    abort 'Gemfile require did not record Minitest timings'
  end
end

puts 'Installed Minitest consumer passed.'
