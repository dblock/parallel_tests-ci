# frozen_string_literal: true

require_relative '../../consumer/support'

Consumer.installed_package
fixture = File.expand_path('../suite', __dir__)
Consumer.in_temporary_directory do
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
end

puts 'Installed RSpec consumer passed.'
