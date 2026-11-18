# frozen_string_literal: true

require 'parallel_tests/ci/github'
require 'parallel_tests'
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
    ENV.update('GITHUB_OUTPUT' => 'outputs', 'GITHUB_RUN_ATTEMPT' => '1', 'PTCI_PREFIX' => 'consumer',
               'PTCI_PATTERN' => 'spec/*.rb', 'PTCI_SHARDS' => '8', 'PTCI_RSPEC_OPTIONS' => '[]',
               'PTCI_WORKER_NAME' => 'Installed {shard.number}/{shard.count} ({plan.group_by})')
    File.write('outputs', '')
    ParallelTests::CI::GitHub.prepare
    matrix = JSON.parse(File.readlines('outputs').find { |line| line.start_with?('matrix=') }.delete_prefix('matrix='))
    unless matrix == [{ 'shard' => 1, 'name' => 'Installed 1/2 (filesize)' },
                      { 'shard' => 2, 'name' => 'Installed 2/2 (filesize)' }]
      abort 'Installed package did not render worker names using the capped total'
    end
    run = ParallelTests::CI::Run.new('tmp/parallel_tests_ci/plan')
    path = [File.dirname(Gem.bin_path('rspec-core', 'rspec')), ENV.fetch('PATH')].join(File::PATH_SEPARATOR)
    matrix.each do |entry|
      code = run.run(shard: entry.fetch('shard'), attempt: 1, directory: "results/#{entry.fetch('shard')}",
                     env: { 'PATH' => path })
      abort 'Installed shard failed' unless code.zero?
    end
    timings = run.collect(directory: 'results', output: 'baseline/runtime.log')
    unless timings.keys.sort == %w[spec/first.rb spec/second.rb] &&
           File.readlines('observed.txt', chomp: true).sort == %w[first second]
      abort 'Installed package did not execute every spec exactly once'
    end
  end
end

puts 'Installed package executed and merged both shards successfully.'
