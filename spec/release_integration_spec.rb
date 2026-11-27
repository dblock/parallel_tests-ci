# frozen_string_literal: true

require 'spec_helper'
require 'ruby-gem-release/rspec'

RSpec.describe 'Release references' do # rubocop:disable RSpec/DescribeClass -- This exercises the release workflow.
  include RubyGemRelease::RSpec

  it 'updates README pins only after publishing to an isolated registry', :aggregate_failures,
     skip: Gem.win_platform? && 'The ruby-gem-release test project clears the Windows process environment' do # rubocop:disable RSpec/ExampleLength -- Exercise the complete release across processes.
    with_release_project do |project|
      project.copy_files(path: File.expand_path('..', __dir__),
                         files: %w[README.md tasks/release_version.rb])
      readme = File.read(File.join(project.checkout, 'README.md'))
      action_reference = readme.match(%r{`uses: dblock/parallel_tests-ci@v(\d+)\.\d+\.\d+`})
      raise 'README is missing the versioned standalone action example' unless action_reference

      release_version = "#{action_reference[1].to_i + 1}.0.0"
      project.write('CHANGELOG.md', "# Changelog\n\n## 0.2.0 (Next)\n\n- Release fixture.\n- Your contribution here.\n")
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
      project.release!(version: release_version)
      expect(project.remote_file("v#{release_version}", 'README.md')).to eq(readme.strip)
      expect(project.remote_file('master', 'README.md')).to include(
        "rspec.yml@v#{release_version}", "minitest.yml@v#{release_version}",
        "gem 'parallel_tests-ci', '#{release_version}'",
        "`uses: dblock/parallel_tests-ci@v#{release_version}`"
      )
    end
  end
end
