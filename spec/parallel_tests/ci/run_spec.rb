# frozen_string_literal: true

RSpec.describe ParallelTests::CI::Run, :aggregate_failures do
  include_context 'with a temporary project'

  let(:run) { described_class.prepare(directory: 'plan', pattern: 'spec/*.rb', shards: 2) }
  let(:observed) { File.expand_path('observed.txt') }

  before do
    FileUtils.cp_r(File.expand_path('../../fixtures/suite', __dir__), 'spec')
  end

  def report(shard, attempt: 1, entries: {}, fingerprint: run.fingerprint, folder: "#{shard}-#{attempt}")
    path = File.join('results', folder)
    FileUtils.mkdir_p(path)
    File.write(File.join(path, 'result.json'),
               JSON.generate('plan' => fingerprint, 'shard' => shard, 'attempt' => attempt))
    ParallelTests::CI::RuntimeLog.write(File.join(path, 'runtime.log'), entries)
  end

  it 'caps a dynamic cold-start matrix at the file count and persists its plan' do
    prepared = described_class.prepare(directory: 'plan', pattern: 'spec/*.rb', shards: 8)
    expect(prepared.matrix).to eq([{ shard: 1 }, { shard: 2 }])
    expect(described_class.new('plan').plan).to eq(prepared.plan)
    expect(prepared.plan.fetch('group_by')).to eq('filesize')
  end

  [0, -1, 257, 1.5, 'invalid'].each do |count|
    it "rejects invalid shard count #{count.inspect}" do
      expect { described_class.prepare(directory: 'plan', shards: count) }.to raise_error(ArgumentError)
    end
  end

  it 'rejects unmatched patterns and non-array RSpec options' do
    expect { described_class.prepare(directory: 'plan', pattern: 'missing/*.rb') }
      .to raise_error(ArgumentError, /No spec files/)
    expect { described_class.prepare(directory: 'plan', rspec_options: '--fail-fast') }
      .to raise_error(ArgumentError, /array of strings/)
  end

  it 'falls back centrally for malformed history, including duplicate paths' do
    File.write('history.log', "spec/first.rb:1\nspec/first.rb:2\n")
    prepared = nil
    expect { prepared = described_class.prepare(directory: 'plan', pattern: 'spec/*.rb', history: 'history.log') }
      .to output(/Ignoring unusable timing history/).to_stderr
    expect(prepared.plan.fetch('group_by')).to eq('filesize')
  end

  it 'discards stale paths and uses filesize when fewer than half of the files are known' do
    File.write('spec/third.rb', '')
    File.write('history.log', "spec/first.rb:1\nspec/deleted.rb:9\n")
    prepared = described_class.prepare(directory: 'plan', pattern: 'spec/*.rb', history: 'history.log')
    expect(prepared.plan.fetch('group_by')).to eq('filesize')
    expect(File.read('plan/runtime.log')).to eq("spec/first.rb:1.0\n")
  end

  it 'runs every cold-start file exactly once across real parallel_rspec subprocesses' do
    run.matrix.each do |entry|
      expect(run.run(shard: entry.fetch(:shard), attempt: 1, directory: "results/#{entry.fetch(:shard)}",
                     env: { 'PTCI_OBSERVED' => observed })).to eq(0)
    end
    combined = run.collect(directory: 'results', output: 'baseline/runtime.log')
    expect(File.readlines(observed, chomp: true).sort).to eq(%w[first second])
    expect(combined.keys.sort).to eq(%w[spec/first.rb spec/second.rb])
  end

  it 'uses one runtime snapshot and upstream unknown-duration estimation for new files' do
    File.write('history.log', "spec/first.rb:0\n")
    prepared = described_class.prepare(directory: 'plan', pattern: 'spec/*.rb', shards: 2, history: 'history.log',
                                       rspec_options: ['--seed', '123'])
    expect(prepared.plan.fetch('group_by')).to eq('runtime')
    prepared.matrix.each do |entry|
      expect(prepared.run(shard: entry.fetch(:shard), attempt: 1, directory: "results/#{entry.fetch(:shard)}",
                          env: { 'PTCI_OBSERVED' => observed })).to eq(0)
    end
    expect(File.readlines(observed, chomp: true).sort).to eq(%w[first second])
    expect(File.read('plan/runtime.log')).to eq("spec/first.rb:0.0\n")
  end

  it 'propagates real RSpec failures and removes an older success marker' do
    prepared = described_class.prepare(directory: 'plan', pattern: 'spec/*.rb', shards: 1)
    expect(prepared.run(shard: 1, attempt: 1, directory: 'result', env: { 'PTCI_OBSERVED' => observed })).to eq(0)
    expect(prepared.run(shard: 1, attempt: 2, directory: 'result',
                        env: { 'PTCI_OBSERVED' => observed, 'PTCI_FAIL' => 'true' })).to eq(1)
    expect(File).not_to exist('result/result.json')
  end

  it 'refuses a changed file set or sizes rather than repartitioning differently on one worker' do
    run
    File.write('spec/first.rb', 'changed')
    expect { run.run(shard: 1, attempt: 1, directory: 'result') }
      .to raise_error(ArgumentError, /changed after preparation/)
    expect { run.run(shard: 3, attempt: 1, directory: 'result') }
      .to raise_error(ArgumentError, /outside the prepared matrix/)
  end

  it 'merges the newest successful retry of each shard while ignoring another plan' do
    report(1, entries: { 'spec/first.rb' => 1 })
    report(1, attempt: 10, entries: { 'spec/first.rb' => 2 })
    report(2, entries: { 'spec/second.rb' => 3 })
    report(2, attempt: 20, fingerprint: 'different-plan')
    expect(run.collect(directory: 'results', output: 'baseline.log'))
      .to eq('spec/first.rb' => 2.0, 'spec/second.rb' => 3.0)
  end

  it 'rejects incomplete or unexpected shard sets' do
    report(1, entries: { 'spec/first.rb' => 1 })
    expect { run.collect(directory: 'results', output: 'baseline.log') }.to raise_error(ArgumentError, /Incomplete/)
    report(3)
    expect { run.collect(directory: 'results', output: 'baseline.log') }.to raise_error(ArgumentError, /unexpected/)
  end

  it 'rejects duplicate reports for an attempt' do
    report(1)
    report(1, folder: 'duplicate')
    report(2)
    expect do
      run.collect(directory: 'results', output: 'baseline.log')
    end.to raise_error(ArgumentError, /Duplicate reports/)
  end

  it 'rejects nonpositive attempts' do
    report(1, attempt: 0)
    report(2)
    expect do
      run.collect(directory: 'results', output: 'baseline.log')
    end.to raise_error(ArgumentError, /positive integer/)
  end

  it 'requires some measurements but accepts an empty successful shard' do
    report(1)
    report(2)
    expect do
      run.collect(directory: 'results', output: 'baseline.log')
    end.to raise_error(ArgumentError, /No test timings/)
    report(1, entries: { 'spec/first.rb' => 1 })
    expect(run.collect(directory: 'results', output: 'baseline.log')).to eq('spec/first.rb' => 1.0)
  end
end
