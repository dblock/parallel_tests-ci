# frozen_string_literal: true

require_relative '../shared/runner'

RSpec.describe ParallelTests::CI::Run, :aggregate_failures do
  include_context 'with a framework suite'

  let(:suite) do
    { framework: 'minitest', directory: 'test', pattern: 'test/*_test.rb',
      files: %w[test/first_test.rb test/second_test.rb], suffix: '_test.rb',
      options: ['--name', '/test_first|no match/'], timings: include('test/first_test.rb') }
  end

  it_behaves_like 'a framework runner'
end
