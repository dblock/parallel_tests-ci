# frozen_string_literal: true

require 'bundler/gem_helper'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'tmpdir'
require 'ruby-gem-release/workflow/ruby_gem'
require 'ruby-gem-release/changelog'
require_relative 'lib/parallel_tests/ci/version'
require_relative 'tasks/release_version'

Bundler::GemHelper.install_tasks
RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new(:rubocop)

desc 'Lint Ruby, Markdown, and spelling'
task lint: :rubocop

desc 'Build, inspect, and load the actual gem in a temporary consumer'
task package: :build do
  artifact = File.expand_path("pkg/parallel_tests-ci-#{ParallelTests::CI::VERSION}.gem")
  package = Gem::Package.new(artifact)
  expected = %w[CHANGELOG.md LICENSE.txt README.md UPGRADING.md] + Dir['lib/**/*.rb']
  abort 'Unexpected packaged files' unless package.spec.files.sort == expected.sort

  Dir.mktmpdir('parallel-tests-ci-consumer') do |directory|
    Bundler.with_unbundled_env do
      env = { 'GEM_HOME' => directory, 'GEM_PATH' => [directory, *Gem.path].join(File::PATH_SEPARATOR) }
      sh env, Gem.ruby, '-S', 'gem', 'install', '--local', '--no-document', artifact
      %w[rspec minitest].each do |framework|
        sh env, Gem.ruby, "spec/parallel_tests/ci/#{framework}/consumer/verify.rb", directory
      end
      sh env, Gem.ruby, 'spec/parallel_tests/ci/consumer/verify_frameworks.rb', directory
    end
  end
end

RubyGemRelease::Workflow::RubyGem.new(
  version: ReleaseVersion.new(path: 'lib/parallel_tests/ci/version.rb', constant: 'VERSION'),
  changelog: RubyGemRelease::Changelog::Intridea.new
).install_tasks

task default: %i[spec lint]
