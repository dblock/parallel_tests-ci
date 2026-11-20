# frozen_string_literal: true

RSpec.describe ParallelTests::CI::Run, :aggregate_failures do
  include_context 'with a temporary project'

  let(:run) { described_class.prepare(directory: 'plan', pattern: 'suite/*.rb', shards: 2) }

  before do
    FileUtils.mkdir_p('suite')
    File.write('suite/first.rb', 'first')
    File.write('suite/second.rb', 'second')
  end

  def report(shard, attempt: 1, entries: {}, fingerprint: run.fingerprint, folder: "#{shard}-#{attempt}")
    path = File.join('results', folder)
    FileUtils.mkdir_p(path)
    File.write(File.join(path, 'result.json'),
               JSON.generate('plan' => fingerprint, 'shard' => shard, 'attempt' => attempt))
    ParallelTests::CI::RuntimeLog.write(File.join(path, 'runtime.log'), entries)
  end

  it 'caps a dynamic cold-start matrix at the file count and persists its plan' do
    prepared = described_class.prepare(directory: 'plan', pattern: 'suite/*.rb', shards: 8)
    expect(prepared.matrix).to eq([{ shard: 1 }, { shard: 2 }])
    expect(described_class.new('plan').plan).to eq(prepared.plan)
    expect(prepared.plan.fetch('group_by')).to eq('filesize')
  end

  it 'assigns each cold-start file to a nonempty matrix entry' do
    prepared = described_class.prepare(directory: 'plan', pattern: 'suite/*.rb', shards: 8)
    entries = prepared.file_matrix
    expect(entries.map { |entry| entry.fetch(:shard) }).to eq([1, 2])
    expect(entries.flat_map { |entry| entry.fetch(:files) }.sort).to eq(%w[suite/first.rb suite/second.rb])
    expect(entries.map { |entry| entry.fetch(:files).size }).to eq([1, 1])
  end

  it 'assigns files using historical durations rather than file sizes' do
    { 'first' => 100, 'second' => 1, 'third' => 1, 'fourth' => 100 }.each do |name, bytes|
      File.write("suite/#{name}.rb", ' ' * bytes)
    end
    File.write('baseline.log', "suite/first.rb:8\nsuite/second.rb:5\nsuite/third.rb:4\nsuite/fourth.rb:1\n")
    prepared = described_class.prepare(directory: 'plan', pattern: 'suite/*.rb', shards: 2, history: 'baseline.log',
                                       group_by: 'runtime')
    expected = [%w[suite/first.rb suite/fourth.rb], %w[suite/second.rb suite/third.rb]]
    expect(prepared.file_matrix.map { |entry| entry.fetch(:files) }).to match_array(expected)
  end

  it 'fails strict runtime planning when fewer than half of the selected files have timings' do
    File.write('suite/third.rb', '')
    File.write('history.log', "suite/first.rb:1\nsuite/deleted.rb:9\n")
    expect do
      described_class.prepare(directory: 'plan', pattern: 'suite/*.rb', history: 'history.log', group_by: 'runtime')
    end.to raise_error(ArgumentError, /usable timings for at least half/)
    expect(File).not_to exist('plan/plan.json')
  end

  it 'rejects unknown grouping strategies' do
    expect do
      described_class.prepare(directory: 'plan', pattern: 'suite/*.rb', group_by: 'steps')
    end.to raise_error(ArgumentError, /expected auto, filesize, or runtime/)
  end

  [0, -1, 257, 1.5, 'invalid'].each do |count|
    it "rejects invalid shard count #{count.inspect}" do
      expect { described_class.prepare(directory: 'plan', shards: count) }.to raise_error(ArgumentError)
    end
  end

  it 'rejects unmatched patterns' do
    expect { described_class.prepare(directory: 'plan', pattern: 'missing/*.rb') }
      .to raise_error(ArgumentError, /No spec files/)
  end

  it 'rejects non-array test options' do
    expect { described_class.prepare(directory: 'plan', test_options: '--fail-fast') }
      .to raise_error(ArgumentError, /array of strings/)
  end

  it 'rejects test options containing non-strings' do
    expect { described_class.prepare(directory: 'plan', test_options: ['--seed', 123]) }
      .to raise_error(ArgumentError, /array of strings/)
  end

  it 'falls back centrally for malformed history, including duplicate paths' do
    File.write('history.log', "suite/first.rb:1\nsuite/first.rb:2\n")
    prepared = nil
    expect { prepared = described_class.prepare(directory: 'plan', pattern: 'suite/*.rb', history: 'history.log') }
      .to output(/Ignoring unusable timing history/).to_stderr
    expect(prepared.plan.fetch('group_by')).to eq('filesize')
  end

  it 'discards stale paths and uses filesize when fewer than half of the files are known' do
    File.write('suite/third.rb', '')
    File.write('history.log', "suite/first.rb:1\nsuite/deleted.rb:9\n")
    prepared = described_class.prepare(directory: 'plan', pattern: 'suite/*.rb', history: 'history.log')
    expect(prepared.plan.fetch('group_by')).to eq('filesize')
    expect(File.read('plan/runtime.log')).to eq("suite/first.rb:1.0\n")
  end

  it 'rejects files resized after preparation' do
    run
    File.write('suite/first.rb', 'changed')
    expect { run.run(shard: 1, attempt: 1, directory: 'result') }
      .to raise_error(ArgumentError, /changed after preparation/)
  end

  it 'rejects shards outside the prepared matrix' do
    expect { run.run(shard: 3, attempt: 1, directory: 'result') }
      .to raise_error(ArgumentError, /outside the prepared matrix/)
  end

  it 'merges the newest successful retry of each shard while ignoring another plan' do
    report(1, entries: { 'suite/first.rb' => 1 })
    report(1, attempt: 10, entries: { 'suite/first.rb' => 2 })
    report(2, entries: { 'suite/second.rb' => 3 })
    report(2, attempt: 20, fingerprint: 'different-plan')
    expect(run.collect(directory: 'results', output: 'baseline.log'))
      .to eq('suite/first.rb' => 2.0, 'suite/second.rb' => 3.0)
  end

  it 'rejects incomplete shard reports' do
    report(1, entries: { 'suite/first.rb' => 1 })
    expect { run.collect(directory: 'results', output: 'baseline.log') }.to raise_error(ArgumentError, /Incomplete/)
  end

  it 'rejects unexpected shard reports' do
    report(1)
    report(2)
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

  it 'requires some measurements across successful shards' do
    report(1)
    report(2)
    expect do
      run.collect(directory: 'results', output: 'baseline.log')
    end.to raise_error(ArgumentError, /No test timings/)
  end

  it 'accepts an empty successful shard when another shard has timings' do
    report(1, entries: { 'suite/first.rb' => 1 })
    report(2)
    expect(run.collect(directory: 'results', output: 'baseline.log')).to eq('suite/first.rb' => 1.0)
  end
end
