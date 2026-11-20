# frozen_string_literal: true

require 'parallel_tests/ci/github'

RSpec.shared_context 'with GitHub workflow inputs' do
  include_context 'with a temporary project'

  let(:environment) do
    { 'GITHUB_EVENT_PATH' => 'event.json', 'GITHUB_OUTPUT' => 'outputs', 'GITHUB_REPOSITORY' => 'owner/project',
      'GITHUB_RUN_ID' => '21', 'GITHUB_RUN_ATTEMPT' => '2' }
  end

  let(:base_inputs) do
    { 'artifact-prefix' => 'test-ci', 'pattern' => 'suite/*.rb', 'shards' => 1, 'test-options' => '[]',
      'framework' => 'rspec' }
  end

  let(:inputs) { base_inputs }

  before do
    File.write('event.json', JSON.generate('repository' => { 'default_branch' => 'master' }))
    File.write('outputs', '')
    allow(ENV).to receive(:fetch).and_call_original
    environment.each { |key, value| allow(ENV).to receive(:fetch).with(key).and_return(value) }
  end

  def outputs
    File.readlines('outputs', chomp: true).to_h { |line| line.split('=', 2) }
  end
end

RSpec.shared_examples 'GitHub shard execution' do
  around do |example|
    original = ENV.fetch('PTCI_OBSERVED', nil)
    ENV['PTCI_OBSERVED'] = 'observed.txt'
    example.run
  ensure
    original.nil? ? ENV.delete('PTCI_OBSERVED') : ENV['PTCI_OBSERVED'] = original
  end

  it 'executes assigned files, names measurement artifacts, and collects timings', :aggregate_failures do
    described_class.prepare(inputs: inputs)
    expect { described_class.run(inputs: inputs, shard: 1) }
      .to raise_error(SystemExit) { |error| expect(error.status).to eq(0) }
    FileUtils.mkdir_p('tmp/parallel_tests_ci/results')
    FileUtils.cp_r('tmp/parallel_tests_ci/result', 'tmp/parallel_tests_ci/results/shard')
    described_class.collect
    expect(outputs.fetch('artifact')).to eq('test-ci-shard-1-2')
    expect(ParallelTests::CI::RuntimeLog.read('tmp/parallel_tests_ci/baseline/runtime.log').keys.sort)
      .to eq(expected_files)
    expect(File.readlines('observed.txt', chomp: true).sort).to eq(%w[first second])
  end
end
