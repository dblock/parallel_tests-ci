# frozen_string_literal: true

require 'minitest/autorun'

if (path = ENV.fetch('PTCI_RUNTIME_LOG', nil))
  require 'parallel_tests/test/runtime_logger'
  ParallelTests::Test::RuntimeLogger.logfile = path
end
