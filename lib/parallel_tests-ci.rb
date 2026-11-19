# frozen_string_literal: true

rspec = defined?(RSpec)
minitest = defined?(Minitest)

if rspec && minitest
  raise LoadError, "Both RSpec and Minitest are loaded. Use require: 'parallel_tests/ci/rspec' for RSpec " \
                   "or require: 'parallel_tests/ci/minitest' for Minitest."
elsif minitest
  require_relative 'parallel_tests/ci/minitest'
elsif rspec
  require_relative 'parallel_tests/ci/rspec'
else
  raise LoadError, "Neither RSpec nor Minitest is loaded. Load one before requiring 'parallel_tests-ci'."
end
