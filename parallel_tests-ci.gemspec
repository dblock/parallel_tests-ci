# frozen_string_literal: true

require_relative 'lib/parallel_tests/ci/version'

Gem::Specification.new do |spec|
  spec.name = 'parallel_tests-ci'
  spec.version = ParallelTests::CI::VERSION
  spec.authors = ['Daniel Doubrovkine']
  spec.email = ['dblock@users.noreply.github.com']
  spec.summary = 'Shared GitHub Actions integration for parallel_tests timing history.'
  spec.description = 'Prepare and reuse CI timing history while parallel_tests owns test collection and sharding.'
  spec.homepage = 'https://github.com/dblock/parallel_tests-ci'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.3'
  spec.files = %w[CHANGELOG.md LICENSE.txt README.md] + Dir['lib/**/*.rb']
  spec.require_paths = ['lib']
  spec.metadata = {
    'bug_tracker_uri' => "#{spec.homepage}/issues",
    'changelog_uri' => "#{spec.homepage}/blob/master/CHANGELOG.md",
    'source_code_uri' => spec.homepage,
    'rubygems_mfa_required' => 'true'
  }

  spec.add_dependency 'parallel_tests', '~> 5.9'
end
