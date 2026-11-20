# frozen_string_literal: true

require 'open3'

RSpec.describe 'Standalone shard matrix', :aggregate_failures do # rubocop:disable RSpec/DescribeClass -- This spec executes the action's script.
  include_context 'with a temporary project'

  let(:script) { File.expand_path('../../../script/shard_matrix.rb', __dir__) }
  let(:output) { File.expand_path('github-output') }
  let(:inputs) do
    { 'framework' => 'rspec', 'pattern' => '', 'shards' => '2', 'group-by' => 'auto', 'runtime-log' => '' }
  end

  before do
    FileUtils.mkdir_p(%w[spec test])
    File.write('spec/first_spec.rb', 'first')
    File.write('spec/second_spec.rb', 'second')
    File.write('test/first_test.rb', 'first')
    File.write('test/second_test.rb', 'second')
  end

  def plan(overrides = {})
    environment = { 'GITHUB_OUTPUT' => output, 'PTCI_INPUTS' => JSON.generate(inputs.merge(overrides)) }
    Open3.capture3(environment, Gem.ruby, script)
  end

  def action_output
    File.readlines(output, chomp: true).to_h { |line| line.split('=', 2) }
  end

  def assigned_files
    JSON.parse(action_output.fetch('matrix')).flat_map { |entry| entry.fetch('files') }.sort
  end

  it 'assigns RSpec files using the default pattern' do
    _stdout, stderr, status = plan
    expect(status.success?).to be(true), stderr
    expect(assigned_files).to eq(%w[spec/first_spec.rb spec/second_spec.rb])
    expect(action_output.fetch('group-by')).to eq('filesize')
  end

  it 'uses the Minitest default pattern and supplied runtime history' do
    File.write('history.log', "test/first_test.rb:4\ntest/second_test.rb:2\n")
    _stdout, stderr, status = plan('framework' => 'minitest', 'group-by' => 'runtime', 'runtime-log' => 'history.log')
    expect(status.success?).to be(true), stderr
    expect(assigned_files).to eq(%w[test/first_test.rb test/second_test.rb])
    expect(action_output.fetch('group-by')).to eq('runtime')
  end

  it 'uses an explicit pattern for the selected framework' do
    _stdout, stderr, status = plan('framework' => 'minitest', 'pattern' => 'test/second_test.rb')
    expect(status.success?).to be(true), stderr
    expect(assigned_files).to eq(['test/second_test.rb'])
  end

  it 'rejects unsupported frameworks' do
    _stdout, stderr, status = plan('framework' => 'unknown')
    expect(status.success?).to be(false)
    expect(stderr).to include('Unsupported test framework: unknown')
    expect(File).not_to exist(output)
  end

  it 'preserves spaces and quotes in an explicit pattern' do
    File.write('test/quoted "file"_test.rb', 'test')
    _stdout, stderr, status = plan('framework' => 'minitest', 'pattern' => 'test/quoted "file"_test.rb')
    expect(status.success?).to be(true), stderr
    expect(assigned_files).to eq(['test/quoted "file"_test.rb'])
  end

  it 'rejects malformed JSON inputs without writing outputs' do
    environment = { 'GITHUB_OUTPUT' => output, 'PTCI_INPUTS' => '{' }
    _stdout, stderr, status = Open3.capture3(environment, Gem.ruby, script)
    expect(status.success?).to be(false)
    expect(stderr).to include(JSON::ParserError.name)
    expect(File).not_to exist(output)
  end
end
