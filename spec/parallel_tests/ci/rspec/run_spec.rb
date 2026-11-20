# frozen_string_literal: true

require_relative '../shared/runner'

RSpec.describe ParallelTests::CI::Run, :aggregate_failures do
  include_context 'with a framework suite'

  let(:suite) do
    { framework: 'rspec', directory: 'spec', pattern: 'spec/*.rb', files: %w[spec/first.rb spec/second.rb],
      suffix: '.rb', options: ['--example', 'First Fixture'], timings: contain_exactly('spec/first.rb') }
  end

  it_behaves_like 'a framework runner'
end
