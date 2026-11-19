# frozen_string_literal: true

require 'rbconfig'
require 'shellwords'

module ParallelTests
  module CI
    # Internal framework selection.
    module Runners
      def self.fetch(framework)
        case framework
        when 'rspec' then RSpec.new
        when 'minitest' then Minitest.new
        else raise ArgumentError, "Unsupported test framework: #{framework}"
        end
      end

      # Runs one group using the shared parallel_tests command and process handling.
      class Base
        def run(flags, files:, options:, output:, env:)
          pid = Process.spawn(env.merge(timing_environment(output)), *command(flags, files, options, output))
          _pid, status = Process.wait2(pid)
          status.exitstatus || (128 + status.termsig)
        end

        def timing_hint
          ''
        end

        private

        def command(flags, files, options, output)
          [RbConfig.ruby, Gem.bin_path('parallel_tests', executable), *flags,
           '--test-options', Shellwords.join(test_options(options, output)), '--', *files]
        end

        def test_options(_options, _output)
          []
        end

        def timing_environment(_output)
          {}
        end
      end

      # Records RSpec timings through the upstream formatter.
      class RSpec < Base
        def default_pattern
          'spec/**/*_spec.rb'
        end

        def file_kind
          'spec'
        end

        private

        def executable
          'parallel_rspec'
        end

        def test_options(options, output)
          options + ['--format', 'progress', '--format', 'ParallelTests::RSpec::RuntimeLogger', '--out', output]
        end
      end

      # Lets the caller's Minitest helper configure the upstream logger.
      class Minitest < Base
        def default_pattern
          'test/**/*_test.rb'
        end

        def file_kind
          'test'
        end

        def timing_hint
          '; configure the Minitest runtime logger in your test helper'
        end

        private

        def executable
          'parallel_test'
        end

        def timing_environment(output)
          { 'PTCI_RUNTIME_LOG' => output }
        end
      end
    end
  end
end
