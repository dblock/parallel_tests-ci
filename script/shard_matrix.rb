# frozen_string_literal: true

require 'tmpdir'
require_relative '../lib/parallel_tests/ci'

Dir.mktmpdir('parallel-tests-ci-matrix') do |directory|
  inputs = JSON.parse(ENV.fetch('PTCI_INPUTS'))
  history = inputs.fetch('runtime-log')
  pattern = inputs.fetch('pattern')
  run = ParallelTests::CI::Run.prepare(directory: directory, pattern: pattern.empty? ? nil : pattern,
                                       framework: inputs.fetch('framework'), shards: inputs.fetch('shards'),
                                       history: history.empty? ? nil : history, group_by: inputs.fetch('group-by'))
  File.open(ENV.fetch('GITHUB_OUTPUT'), 'a') do |output|
    output.puts "matrix=#{JSON.generate(run.file_matrix)}"
    output.puts "group-by=#{run.plan.fetch('group_by')}"
  end
end
