# frozen_string_literal: true

require 'open3'

RSpec.describe 'Standalone shard matrix', :aggregate_failures do # rubocop:disable RSpec/DescribeClass -- This spec executes the action's script.
  include_context 'with a temporary project'

  let(:script) { File.expand_path('../../../script/shard_matrix.rb', __dir__) }
  let(:output) { File.expand_path('github-output') }
  let(:environment) do
    { 'GITHUB_OUTPUT' => output, 'PTCI_PATTERN' => '', 'PTCI_SHARDS' => '2',
      'PTCI_GROUP_BY' => 'auto', 'PTCI_RUNTIME_LOG' => '', 'PTCI_FRAMEWORK' => 'rspec' }
  end

  before do
    FileUtils.mkdir_p(%w[spec test])
    File.write('spec/first_spec.rb', 'first')
    File.write('spec/second_spec.rb', 'second')
    File.write('test/first_test.rb', 'first')
    File.write('test/second_test.rb', 'second')
  end

  def plan(overrides = {})
    Open3.capture3(environment.merge(overrides), Gem.ruby, script)
  end

  def action_output
    File.readlines(output, chomp: true).to_h { |line| line.split('=', 2) }
  end

  def assigned_files
    JSON.parse(action_output.fetch('matrix')).flat_map { |entry| entry.fetch('files') }.sort
  end

  it 'defaults to RSpec and assigns the matching files' do
    _stdout, stderr, status = plan
    expect(status.success?).to be(true), stderr
    expect(assigned_files).to eq(%w[spec/first_spec.rb spec/second_spec.rb])
    expect(action_output.fetch('group-by')).to eq('filesize')
  end

  it 'retains the RSpec default when the framework environment variable is absent' do
    _stdout, stderr, status = plan('PTCI_FRAMEWORK' => nil)
    expect(status.success?).to be(true), stderr
    expect(assigned_files).to eq(%w[spec/first_spec.rb spec/second_spec.rb])
  end

  it 'uses the Minitest default pattern and supplied runtime history' do
    File.write('history.log', "test/first_test.rb:4\ntest/second_test.rb:2\n")
    _stdout, stderr, status = plan('PTCI_FRAMEWORK' => 'minitest', 'PTCI_GROUP_BY' => 'runtime',
                                   'PTCI_RUNTIME_LOG' => 'history.log')
    expect(status.success?).to be(true), stderr
    expect(assigned_files).to eq(%w[test/first_test.rb test/second_test.rb])
    expect(action_output.fetch('group-by')).to eq('runtime')
  end

  it 'uses an explicit pattern for the selected framework' do
    _stdout, stderr, status = plan('PTCI_FRAMEWORK' => 'minitest', 'PTCI_PATTERN' => 'test/second_test.rb')
    expect(status.success?).to be(true), stderr
    expect(assigned_files).to eq(['test/second_test.rb'])
  end

  it 'rejects unsupported frameworks' do
    _stdout, stderr, status = plan('PTCI_FRAMEWORK' => 'unknown')
    expect(status.success?).to be(false)
    expect(stderr).to include('Unsupported test framework: unknown')
    expect(File).not_to exist(output)
  end
end
