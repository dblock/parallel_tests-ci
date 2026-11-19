# frozen_string_literal: true

require 'parallel_tests/ci/github'
require 'tmpdir'

module Consumer
  def self.installed_package
    installation = File.realpath(ARGV.fetch(0))
    package = Gem.loaded_specs.fetch('parallel_tests-ci')
    unless File.realpath(package.full_gem_path).start_with?("#{installation}/")
      abort 'Consumer loaded source instead of the installed archive'
    end
    package
  end

  def self.in_temporary_directory(&block)
    Dir.mktmpdir('parallel-tests-ci-installed') { |directory| Dir.chdir(directory, &block) }
  end
end
