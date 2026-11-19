# frozen_string_literal: true

path = ENV.fetch('PTCI_RUNTIME_LOG', '')
unless path.empty?
  require 'minitest'
  require 'parallel_tests/test/runtime_logger'

  ParallelTests::Test::RuntimeLogger.logfile = path
end
