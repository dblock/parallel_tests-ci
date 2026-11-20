# frozen_string_literal: true

require 'simplecov'
SimpleCov.start

require 'parallel_tests/ci'
require 'tmpdir'

RSpec.shared_context 'with a temporary project' do
  around do |example|
    Dir.mktmpdir('parallel-tests-ci-spec') { |directory| Dir.chdir(directory) { example.run } }
  end

  def copy_suite(fixture, destination)
    FileUtils.cp_r(File.expand_path("parallel_tests/ci/#{fixture}/suite", __dir__), destination)
  end
end

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.order = :random
  config.example_status_persistence_file_path = '.rspec_status'
  config.expect_with(:rspec) { |expectations| expectations.syntax = :expect }
end
