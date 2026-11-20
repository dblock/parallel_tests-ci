# frozen_string_literal: true

require_relative '../shared/runner'

RSpec.describe ParallelTests::CI::Run, :aggregate_failures do
  include_context 'with a framework suite'

  let(:suite) do
    { framework: 'rspec', directory: 'spec', pattern: 'spec/*.rb', files: %w[spec/first.rb spec/second.rb],
      suffix: '.rb', options: ['--example', 'First Fixture'], timings: contain_exactly('spec/first.rb') }
  end

  it_behaves_like 'a framework runner'

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

  it 'uses one runtime snapshot and upstream unknown-duration estimation for new files' do
    File.write('history.log', "spec/first.rb:0\n")
    prepared = described_class.prepare(directory: 'plan', pattern: 'spec/*.rb', shards: 2, history: 'history.log',
                                       test_options: ['--seed', '123'])
    expect(prepared.plan.fetch('group_by')).to eq('runtime')
    run_shards(prepared)
    expect(File.readlines(observed, chomp: true).sort).to eq(%w[first second])
    expect(File.read('plan/runtime.log')).to eq("spec/first.rb:0.0\n")
  end
end
