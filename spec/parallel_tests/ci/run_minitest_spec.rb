# frozen_string_literal: true

RSpec.describe ParallelTests::CI::Run, :aggregate_failures do
  include_context 'with a temporary project'

  let(:observed) { File.expand_path('observed.txt') }
  let(:files) { %w[test/first_test.rb test/second_test.rb] }

  before { copy_suite('minitest', 'test') }

  def run_suite(label, history: nil)
    prepared = described_class.prepare(directory: "plan-#{label}", framework: 'minitest', shards: 2, history: history)
    prepared.matrix.each { |entry| run_shard(prepared, label, entry.fetch(:shard)) }
    timings = prepared.collect(directory: "results-#{label}", output: "#{label}.log")
    expect(timings.keys.sort).to eq(files)
    prepared.plan.fetch('group_by')
  end

  def run_shard(prepared, label, shard)
    before = observed_lines.size
    expect(prepared.run(shard: shard, attempt: 1, directory: "results-#{label}/#{shard}",
                        env: { 'PTCI_OBSERVED' => observed })).to eq(0)
    expect_shard_assignment(prepared, shard, before: before, suffix: '_test.rb')
  end

  it 'collects a cold baseline and reuses it to run every file once in the warm suite' do
    expect(run_suite('cold')).to eq('filesize')
    expect(File.readlines(observed, chomp: true).sort).to eq(%w[first second])
    File.write(observed, '')
    expect(run_suite('warm', history: 'cold.log')).to eq('runtime')
    expect(File.readlines(observed, chomp: true).sort).to eq(%w[first second])
  end

  it 'propagates Minitest failures without leaving a success marker' do
    prepared = described_class.prepare(directory: 'plan', framework: 'minitest', pattern: 'test/first_test.rb')
    env = { 'PTCI_OBSERVED' => observed, 'PTCI_FAIL' => 'true' }
    expect(prepared.run(shard: 1, attempt: 1, directory: 'result', env: env)).to eq(1)
    expect(File).not_to exist('result/result.json')
  end

  it 'passes test options with spaces to Minitest while preserving timing collection' do
    prepared = described_class.prepare(directory: 'plan', framework: 'minitest', shards: 1,
                                       test_options: ['--name', '/test_first|no match/'])
    expect(prepared.run(shard: 1, attempt: 1, directory: 'results/1', env: { 'PTCI_OBSERVED' => observed })).to eq(0)
    expect(File.readlines(observed, chomp: true)).to eq(['first'])
    expect(prepared.collect(directory: 'results', output: 'baseline.log').keys).to include('test/first_test.rb')
  end
end
