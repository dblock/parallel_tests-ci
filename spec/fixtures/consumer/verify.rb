# frozen_string_literal: true

require 'parallel_tests/ci'
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
    run = ParallelTests::CI::Run.prepare(directory: 'plan', pattern: 'spec/*.rb', shards: 2)
    path = [File.dirname(Gem.bin_path('rspec-core', 'rspec')), ENV.fetch('PATH')].join(File::PATH_SEPARATOR)
    run.matrix.each do |entry|
      code = run.run(shard: entry.fetch(:shard), attempt: 1, directory: "results/#{entry.fetch(:shard)}",
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
