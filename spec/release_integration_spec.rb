# frozen_string_literal: true

require 'spec_helper'
require 'ruby-gem-release/rspec'

RSpec.describe 'Release references' do # rubocop:disable RSpec/DescribeClass -- This exercises the release workflow.
  include RubyGemRelease::RSpec

  it 'updates README pins only after publishing to an isolated registry', :aggregate_failures do # rubocop:disable RSpec/ExampleLength -- Exercise the complete release across processes.
    with_release_project do |project|
      project.copy_files(path: File.expand_path('..', __dir__),
                         files: %w[README.md CHANGELOG.md tasks/release_version.rb])
      project.write('lib/example/version.rb', "VERSION = '0.2.0'\n")
      project.write('example.gemspec', <<~RUBY)
        require_relative 'lib/example/version'
        Gem::Specification.new do |spec|
          spec.name = 'example'
          spec.version = VERSION
          spec.authors = ['Fixture']
          spec.summary = 'Release fixture'
          spec.files = ['lib/example/version.rb', 'README.md']
        end
      RUBY
      # rubocop:disable-next Spellcheck/Spelling -- This heredoc is executable Ruby, not prose.
      project.write('Rakefile', <<~RUBY)
        require 'ruby-gem-release/rspec'
        require 'ruby-gem-release/workflow/ruby_gem'
        require 'ruby-gem-release/changelog'
        require_relative 'tasks/release_version'
        RubyGemRelease::Workflow::RubyGem.new(
          version: ReleaseVersion.new(path: 'lib/example/version.rb', constant: 'VERSION'),
          changelog: RubyGemRelease::Changelog::Intridea.new,
          provider: RubyGemRelease::RSpec::Provider.new,
          destination: RubyGemRelease::RSpec::Destination.new,
          hosting: RubyGemRelease::RSpec::Hosting.new
        ).install_tasks
      RUBY
      project.commit!
      project.release!(version: '0.3.0')
      expect(project.remote_file('v0.3.0', 'README.md')).to include(
        'rspec.yml@v0.2.0', '`uses: dblock/parallel_tests-ci@v0.2.0`'
      )
      expect(project.remote_file('master', 'README.md')).to include(
        'rspec.yml@v0.3.0', 'minitest.yml@v0.3.0', "gem 'parallel_tests-ci', '0.3.0'",
        '`uses: dblock/parallel_tests-ci@v0.3.0`'
      )
    end
  end
end
