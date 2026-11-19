# frozen_string_literal: true

require 'parallel_tests/ci/github'
require 'open3'
require 'tmpdir'

installation = File.realpath(ARGV.fetch(0))
package = Gem.loaded_specs.fetch('parallel_tests-ci')
unless File.realpath(package.full_gem_path).start_with?("#{installation}/")
  abort 'Consumer loaded source instead of the installed archive'
end

fixture = File.expand_path('../suite', __dir__)
Dir.mktmpdir('parallel-tests-ci-installed') do |directory|
  Dir.chdir(directory) do
    FileUtils.cp_r(fixture, 'spec')
    inputs = { 'artifact-prefix' => 'consumer', 'pattern' => 'spec/*.rb', 'shards' => 8,
               'test-options' => JSON.generate(['--seed', '123']),
               'worker-name' => 'Installed "{shard.number}"/{shard.count} ({plan.group_by})' }
    environment = { 'GITHUB_OUTPUT' => 'outputs', 'GITHUB_RUN_ATTEMPT' => '1', 'PTCI_INPUTS' => JSON.generate(inputs) }
    File.write('outputs', '')
    unless system(environment, Gem.ruby, '-rparallel_tests/ci/github', '-e',
                  'ParallelTests::CI::GitHub.prepare(inputs: JSON.parse(ENV.fetch("PTCI_INPUTS")))')
      abort 'Installed package could not prepare JSON workflow inputs'
    end
    matrix = JSON.parse(File.readlines('outputs').find { |line| line.start_with?('matrix=') }.delete_prefix('matrix='))
    unless matrix == [{ 'shard' => 1, 'name' => 'Installed "1"/2 (filesize)' },
                      { 'shard' => 2, 'name' => 'Installed "2"/2 (filesize)' }]
      abort 'Installed package did not render worker names using the capped total'
    end
    run = ParallelTests::CI::Run.new('tmp/parallel_tests_ci/plan')
    abort 'Installed package lost nested JSON arguments' unless run.plan.fetch('test_options') == ['--seed', '123']
    unless run.file_matrix.flat_map { |entry| entry.fetch(:files) }.sort == %w[spec/first.rb spec/second.rb]
      abort 'Installed package did not assign every file to the standalone matrix'
    end
    path = [File.dirname(Gem.bin_path('rspec-core', 'rspec')), ENV.fetch('PATH')].join(File::PATH_SEPARATOR)
    matrix.each do |entry|
      shard = entry.fetch('shard')
      code = run.run(shard: shard, attempt: 1, directory: "results/#{shard}", env: { 'PATH' => path })
      abort 'Installed shard failed' unless code.zero?
    end
    timings = run.collect(directory: 'results', output: 'baseline/runtime.log')
    unless timings.keys.sort == %w[spec/first.rb spec/second.rb] &&
           File.readlines('observed.txt', chomp: true).sort == %w[first second]
      abort 'Installed package did not execute every spec exactly once'
    end

    FileUtils.cp_r(File.expand_path('../minitest', __dir__), 'test')
    minitest_run = ParallelTests::CI::Run.prepare(directory: 'minitest-plan', framework: 'minitest', shards: 1,
                                                  test_options: ['--name', '/test_first|no match/'])
    env = { 'PATH' => path, 'PTCI_OBSERVED' => File.expand_path('minitest-observed.txt') }
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
    unless system(Gem.ruby, '-r', 'rspec', '-r', 'parallel_tests-ci', '-e', '')
      abort 'Default require did not accept RSpec'
    end

    File.write('Gemfile', <<~GEMFILE)
      source 'https://rubygems.org'
      gem 'rspec'
      gem 'minitest', '~> 5.27'
      gem 'parallel_tests-ci', '#{package.version}', require: 'parallel_tests/ci/rspec'
    GEMFILE
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
end

puts 'Installed package executed and collected RSpec and Minitest timings successfully.'
