# frozen_string_literal: true

require 'tmpdir'
require_relative '../lib/parallel_tests/ci'

Dir.mktmpdir('parallel-tests-ci-matrix') do |directory|
  history = ENV.fetch('PTCI_RUNTIME_LOG')
  run = ParallelTests::CI::Run.prepare(directory: directory, pattern: ENV.fetch('PTCI_PATTERN'),
                                       shards: ENV.fetch('PTCI_SHARDS'), history: history.empty? ? nil : history,
                                       group_by: ENV.fetch('PTCI_GROUP_BY', 'auto'))
  File.open(ENV.fetch('GITHUB_OUTPUT'), 'a') do |output|
    output.puts "matrix=#{JSON.generate(run.file_matrix)}"
    output.puts "group-by=#{run.plan.fetch('group_by')}"
  end
end
