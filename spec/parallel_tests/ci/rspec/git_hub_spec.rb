# frozen_string_literal: true

require_relative '../shared/github'

RSpec.describe ParallelTests::CI::GitHub, :aggregate_failures do
  include_context 'with GitHub workflow inputs'

  let(:inputs) { base_inputs.merge('framework' => 'rspec', 'pattern' => 'spec/*.rb') }
  let(:expected_files) { %w[spec/first.rb spec/second.rb] }

  before { copy_suite('rspec', 'spec') }

  it_behaves_like 'GitHub shard execution'
end
