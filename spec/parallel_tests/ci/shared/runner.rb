# frozen_string_literal: true

RSpec.shared_context 'with a framework suite' do
  include_context 'with a temporary project'

  let(:observed) { File.expand_path('observed.txt') }

  before { copy_suite(suite.fetch(:framework), suite.fetch(:directory)) }

  def observed_lines
    File.exist?(observed) ? File.readlines(observed, chomp: true) : []
  end

  def expect_shard_assignment(prepared, shard, before:)
    assignment = prepared.file_matrix.find { |entry| entry.fetch(:shard) == shard }
    assigned = assignment ? assignment.fetch(:files) : []
    expect(observed_lines.drop(before))
      .to match_array(assigned.map { |file| File.basename(file, suite.fetch(:suffix)) })
  end

  def run_shards(prepared, directory: 'results')
    prepared.matrix.each do |entry|
      shard = entry.fetch(:shard)
      before = observed_lines.size
      expect(prepared.run(shard: shard, attempt: 1, directory: "#{directory}/#{shard}",
                          env: { 'PTCI_OBSERVED' => observed })).to eq(0)
      expect_shard_assignment(prepared, shard, before: before)
    end
  end

  def run_suite(label, history: nil)
    prepared = described_class.prepare(directory: "plan-#{label}", framework: suite.fetch(:framework),
                                       pattern: suite.fetch(:pattern), shards: 2, history: history)
    run_shards(prepared, directory: "results-#{label}")
    timings = prepared.collect(directory: "results-#{label}", output: "#{label}.log")
    expect(timings.keys).to match_array(suite.fetch(:files))
    prepared.plan.fetch('group_by')
  end
end

RSpec.shared_examples 'a framework runner' do
  it 'persists the selected framework in its plan' do
    described_class.prepare(directory: 'plan', framework: suite.fetch(:framework), pattern: suite.fetch(:pattern))
    expect(described_class.new('plan').plan.fetch('framework')).to eq(suite.fetch(:framework))
  end

  it 'collects a cold baseline and reuses it to run every file once in the warm suite', :aggregate_failures do
    expect(run_suite('cold')).to eq('filesize')
    expect(observed_lines.sort).to eq(%w[first second])
    File.write(observed, '')
    expect(run_suite('warm', history: 'cold.log')).to eq('runtime')
    expect(observed_lines.sort).to eq(%w[first second])
  end

  it 'propagates failures and removes an older success marker', :aggregate_failures do
    prepared = described_class.prepare(directory: 'plan', framework: suite.fetch(:framework),
                                       pattern: suite.fetch(:pattern), shards: 1)
    env = { 'PTCI_OBSERVED' => observed }
    expect(prepared.run(shard: 1, attempt: 1, directory: 'result', env: env)).to eq(0)
    expect(prepared.run(shard: 1, attempt: 2, directory: 'result', env: env.merge('PTCI_FAIL' => 'true'))).to eq(1)
    expect(File).not_to exist('result/result.json')
  end

  it 'passes test options with spaces while preserving timing collection', :aggregate_failures do
    prepared = described_class.prepare(directory: 'plan', framework: suite.fetch(:framework),
                                       pattern: suite.fetch(:pattern), shards: 1, test_options: suite.fetch(:options))
    expect(prepared.run(shard: 1, attempt: 1, directory: 'results/1', env: { 'PTCI_OBSERVED' => observed })).to eq(0)
    expect(observed_lines).to eq(['first'])
    expect(prepared.collect(directory: 'results', output: 'baseline.log').keys).to suite.fetch(:timings)
  end

  it 'ignores usable history in filesize mode and still collects fresh timings', :aggregate_failures do
    files = suite.fetch(:files)
    File.write('history.log', "#{files.first}:1\n#{files.last}:2\n")
    prepared = described_class.prepare(directory: 'plan', framework: suite.fetch(:framework),
                                       pattern: suite.fetch(:pattern), history: 'history.log', group_by: 'filesize')
    expect(prepared.plan.fetch('group_by')).to eq('filesize')
    expect(File.read('plan/runtime.log')).to be_empty
    run_shards(prepared)
    timings = prepared.collect(directory: 'results', output: 'baseline.log')
    expect(timings.keys).to match_array(files)
  end

  it 'uses one runtime snapshot and upstream unknown-duration estimation for new files', :aggregate_failures do
    first = suite.fetch(:files).first
    File.write('history.log', "#{first}:0\n")
    prepared = described_class.prepare(directory: 'plan', framework: suite.fetch(:framework),
                                       pattern: suite.fetch(:pattern), shards: 2, history: 'history.log',
                                       test_options: ['--seed', '123'])
    expect(prepared.plan.fetch('group_by')).to eq('runtime')
    run_shards(prepared)
    expect(observed_lines.sort).to eq(%w[first second])
    expect(File.read('plan/runtime.log')).to eq("#{first}:0.0\n")
  end
end
