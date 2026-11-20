# frozen_string_literal: true

require_relative '../shared/github'

RSpec.describe ParallelTests::CI::GitHub, :aggregate_failures do
  include_context 'with GitHub workflow inputs'

  let(:inputs) { base_inputs.merge('framework' => 'minitest', 'pattern' => 'test/*_test.rb') }
  let(:expected_files) { %w[test/first_test.rb test/second_test.rb] }

  before { copy_suite('minitest', 'test') }

  it_behaves_like 'GitHub shard execution'
end
