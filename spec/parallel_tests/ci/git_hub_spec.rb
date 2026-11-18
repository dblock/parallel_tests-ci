# frozen_string_literal: true

require 'parallel_tests/ci/github'

RSpec.describe ParallelTests::CI::GitHub, :aggregate_failures do
  include_context 'with a temporary project'

  let(:environment) do
    { 'GITHUB_EVENT_PATH' => 'event.json', 'GITHUB_OUTPUT' => 'outputs', 'GITHUB_REPOSITORY' => 'owner/project',
      'GITHUB_RUN_ID' => '21', 'GITHUB_RUN_ATTEMPT' => '2', 'PTCI_PREFIX' => 'test-ci',
      'PTCI_PATTERN' => 'spec/*.rb', 'PTCI_SHARDS' => '1', 'PTCI_RSPEC_OPTIONS' => '[]', 'PTCI_SHARD' => '1' }
  end

  before do
    File.write('event.json', JSON.generate('repository' => { 'default_branch' => 'master' }))
    File.write('outputs', '')
    allow(ENV).to receive(:fetch).and_call_original
    environment.each { |key, value| allow(ENV).to receive(:fetch).with(key).and_return(value) }
  end

  def response(path, payload, paginate: false)
    arguments = ['gh', 'api', path]
    arguments.push('--paginate', '--slurp') if paginate
    allow(Open3).to receive(:capture3).with(*arguments)
                                      .and_return([JSON.generate(payload), '',
                                                   instance_double(Process::Status, success?: true)])
  end

  def historical_run(id, **overrides)
    { 'id' => id, 'event' => 'push', 'conclusion' => 'success', 'head_branch' => 'master',
      'head_repository' => { 'full_name' => 'owner/project' } }.merge(overrides.transform_keys(&:to_s))
  end

  def history_runs(runs, branch: 'master')
    response('repos/owner/project/actions/runs/21', { 'workflow_id' => 7 })
    response("repos/owner/project/actions/workflows/7/runs?branch=#{branch}&event=push&status=success&per_page=20",
             { 'workflow_runs' => runs })
  end

  it 'ignores PRs, forks, failed runs, missing repositories, and other branches' do
    history_runs([historical_run(1, event: 'pull_request'), historical_run(2, conclusion: 'failure'),
                  historical_run(3, head_repository: { 'full_name' => 'fork/project' }),
                  historical_run(4, head_repository: nil), historical_run(5, head_branch: 'topic')])
    described_class.find_history
    expect(File.read('outputs')).to be_empty
  end

  it 'scans retained older runs and paginated artifacts for the configured prefix' do
    history_runs([historical_run(1), historical_run(2)])
    response('repos/owner/project/actions/runs/1/artifacts?per_page=100',
             [{ 'artifacts' => [{ 'name' => 'test-ci-runtimes', 'expired' => true }] }], paginate: true)
    response('repos/owner/project/actions/runs/2/artifacts?per_page=100',
             [{ 'artifacts' => [] },
              { 'artifacts' => [{ 'id' => 99, 'name' => 'test-ci-runtimes', 'expired' => false }] }],
             paginate: true)
    described_class.find_history
    expect(File.read('outputs')).to eq("history_run=2\nhistory_artifact=99\n")
  end

  it 'escapes default branch names when querying only the caller workflow' do
    File.write('event.json', JSON.generate('repository' => { 'default_branch' => 'release/stable' }))
    history_runs([], branch: 'release%2Fstable')
    described_class.find_history
    expect(File.read('outputs')).to be_empty
  end

  it 'falls back without requiring history access when GitHub rejects the request' do
    allow(Open3).to receive(:capture3).and_return(['', 'forbidden', instance_double(Process::Status, success?: false)])
    expect { described_class.find_history }.to output(/using file sizes: forbidden/).to_stderr
    expect(File.read('outputs')).to be_empty
  end

  it 'falls back when history metadata is not valid JSON' do
    allow(Open3).to receive(:capture3).and_return(['{', '', instance_double(Process::Status, success?: true)])
    expect { described_class.find_history }.to output(/Timing history unavailable/).to_stderr
  end

  it 'rejects unsafe artifact prefixes instead of broadening the artifact search' do
    allow(ENV).to receive(:fetch).with('PTCI_PREFIX').and_return('test-*')
    expect { described_class.prefix }.to raise_error(ArgumentError, /Artifact prefix/)
  end

  it 'drives preparation, real RSpec execution, measurement upload naming, and collection' do
    FileUtils.cp_r(File.expand_path('../../fixtures/suite', __dir__), 'spec')
    described_class.prepare
    expect(File.read('outputs')).to include('matrix=[{"shard":1}]', 'artifact=test-ci-plan-2')
    expect { described_class.run }.to raise_error(SystemExit) { |error| expect(error.status).to eq(0) }
    FileUtils.mkdir_p('tmp/parallel_tests_ci/results')
    FileUtils.cp_r('tmp/parallel_tests_ci/result', 'tmp/parallel_tests_ci/results/shard')
    described_class.collect
    expect(File.read('outputs')).to include('artifact=test-ci-shard-1-2')
    expect(ParallelTests::CI::RuntimeLog.read('tmp/parallel_tests_ci/baseline/runtime.log').size).to eq(2)
  end

  it 'propagates a failed shard without publishing success outputs' do
    runner = instance_double(ParallelTests::CI::Run, run: 17)
    allow(ParallelTests::CI::Run).to receive(:new).with('tmp/parallel_tests_ci/plan').and_return(runner)
    expect { described_class.run }.to raise_error(SystemExit) { |error| expect(error.status).to eq(17) }
    expect(File.read('outputs')).to be_empty
  end
end
