# frozen_string_literal: true

require 'spec_helper'
require_relative '../tasks/release_version'

RSpec.describe ReleaseVersion do
  include_context 'with a temporary project'

  let(:readme) do
    <<~TEXT
      gem 'parallel_tests-ci', '0.1.0', require: false
      dblock/parallel_tests-ci/.github/workflows/rspec.yml@v0.1.0
      dblock/parallel_tests-ci/.github/workflows/minitest.yml@v0.2.0
      dblock/parallel_tests-ci@v0.1.0
      dblock/parallel_tests-ci@v0.1.0-beta
      other/project@v0.1.0
    TEXT
  end

  it 'updates project pins to the released version and leaves other references alone', :aggregate_failures do # rubocop:disable RSpec/ExampleLength -- Check the complete release output and retry together.
    File.write('version.rb', "VERSION = '0.2.0'\n")
    File.write('README.md', readme)
    version = described_class.new(path: 'version.rb', constant: 'VERSION')
    2.times { expect(version.increment!(from: '0.2.0')).to eq('0.2.1') }
    expect(version.read).to eq('0.2.1')
    expect(File.read('README.md')).to eq(<<~TEXT)
      gem 'parallel_tests-ci', '0.2.0', require: false
      dblock/parallel_tests-ci/.github/workflows/rspec.yml@v0.2.0
      dblock/parallel_tests-ci/.github/workflows/minitest.yml@v0.2.0
      dblock/parallel_tests-ci@v0.2.0
      dblock/parallel_tests-ci@v0.1.0-beta
      other/project@v0.1.0
    TEXT
  end

  it 'does not increment when the README is missing', :aggregate_failures do
    File.write('version.rb', "VERSION = '0.2.0'\n")
    version = described_class.new(path: 'version.rb', constant: 'VERSION')
    expect { version.increment! }.to raise_error(Errno::ENOENT)
    expect(version.read).to eq('0.2.0')
  end
end
