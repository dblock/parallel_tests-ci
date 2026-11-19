# frozen_string_literal: true

RSpec.describe ParallelTests::CI::Run, :aggregate_failures do
  include_context 'with a temporary project'

  let(:run) { described_class.prepare(directory: 'plan', pattern: 'spec/*.rb', shards: 2) }
  let(:observed) { File.expand_path('observed.txt') }

  before { copy_rspec_suite }

  def run_shards(prepared)
    prepared.matrix.each do |entry|
      shard = entry.fetch(:shard)
      expect(prepared.run(shard: shard, attempt: 1, directory: "results/#{shard}",
                          env: { 'PTCI_OBSERVED' => observed })).to eq(0)
    end
  end

  it 'ignores usable history in filesize mode and still collects fresh timings' do
    File.write('history.log', "spec/first.rb:1\nspec/second.rb:2\n")
    prepared = described_class.prepare(directory: 'plan', pattern: 'spec/*.rb', history: 'history.log',
                                       group_by: 'filesize')
    expect(prepared.plan.fetch('group_by')).to eq('filesize')
    expect(File.read('plan/runtime.log')).to be_empty
    run_shards(prepared)
    timings = prepared.collect(directory: 'results', output: 'baseline.log')
    expect(timings.keys.sort).to eq(%w[spec/first.rb spec/second.rb])
  end

  it 'runs every cold-start file exactly once across real parallel_rspec subprocesses' do
    run_shards(run)
    combined = run.collect(directory: 'results', output: 'baseline/runtime.log')
    expect(File.readlines(observed, chomp: true).sort).to eq(%w[first second])
    expect(combined.keys.sort).to eq(%w[spec/first.rb spec/second.rb])
  end

  it 'uses one runtime snapshot and upstream unknown-duration estimation for new files' do
    File.write('history.log', "spec/first.rb:0\n")
    prepared = described_class.prepare(directory: 'plan', pattern: 'spec/*.rb', shards: 2, history: 'history.log',
                                       test_options: ['--seed', '123'])
    expect(prepared.plan.fetch('group_by')).to eq('runtime')
    run_shards(prepared)
    expect(File.readlines(observed, chomp: true).sort).to eq(%w[first second])
    expect(File.read('plan/runtime.log')).to eq("spec/first.rb:0.0\n")
  end

  it 'passes test options with spaces to RSpec while preserving timing collection' do
    prepared = described_class.prepare(directory: 'plan', pattern: 'spec/*.rb', shards: 1,
                                       test_options: ['--example', 'First Fixture'])
    expect(prepared.run(shard: 1, attempt: 1, directory: 'results/1', env: { 'PTCI_OBSERVED' => observed })).to eq(0)
    expect(File.readlines(observed, chomp: true)).to eq(['first'])
    expect(prepared.collect(directory: 'results', output: 'baseline.log').keys).to eq(['spec/first.rb'])
  end

  it 'propagates real RSpec failures and removes an older success marker' do
    prepared = described_class.prepare(directory: 'plan', pattern: 'spec/*.rb', shards: 1)
    expect(prepared.run(shard: 1, attempt: 1, directory: 'result', env: { 'PTCI_OBSERVED' => observed })).to eq(0)
    expect(prepared.run(shard: 1, attempt: 2, directory: 'result',
                        env: { 'PTCI_OBSERVED' => observed, 'PTCI_FAIL' => 'true' })).to eq(1)
    expect(File).not_to exist('result/result.json')
  end
end
