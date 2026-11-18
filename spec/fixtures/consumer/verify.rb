# frozen_string_literal: true

require 'parallel_tests/ci'
require 'parallel_tests'

installation = File.realpath(ARGV.fetch(0))
package = Gem.loaded_specs.fetch('parallel_tests-ci')
unless File.realpath(package.full_gem_path).start_with?("#{installation}/")
  abort 'Consumer loaded source instead of the installed archive'
end

puts 'Installed package loaded successfully.'
