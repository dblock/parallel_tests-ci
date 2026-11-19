# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'json'
require 'parallel_tests'
require 'parallel_tests/rspec/runner'
require_relative 'runners'

module ParallelTests
  module CI
    # A shared immutable plan; parallel_tests remains the only partitioner.
    class Run
      attr_reader :directory, :plan

      def self.prepare(directory:, history: nil, group_by: 'auto', **settings)
        plan = configuration(**settings)
        files = plan.fetch('sizes').keys
        known = group_by == 'filesize' ? {} : history_for(history, files)
        plan['group_by'] = grouping(group_by, known.size, files.size)
        FileUtils.mkdir_p(directory)
        File.write(File.join(directory, 'plan.json'), JSON.generate(plan))
        RuntimeLog.write(File.join(directory, 'runtime.log'), known)
        new(directory)
      end

      def self.configuration(pattern: nil, shards: 4, rspec_options: [], framework: 'rspec')
        count = positive_integer(shards)
        raise ArgumentError, 'GitHub Actions allows at most 256 shards' if count > 256
        raise ArgumentError, 'RSpec options must be an array of strings' unless rspec_options.is_a?(Array) && rspec_options.all?(String)

        plan = selection(pattern, framework)
        plan.merge('shards' => [count, plan.fetch('sizes').size].min, 'rspec_options' => rspec_options)
      end

      def self.selection(pattern, framework)
        runner = Runners.fetch(framework)
        pattern ||= runner.default_pattern
        sizes = discover(pattern)
        raise ArgumentError, "No #{runner.file_kind} files match #{pattern.inspect}" if sizes.empty?

        plan = { 'pattern' => pattern, 'sizes' => sizes }
        plan['framework'] = framework unless framework == 'rspec'
        plan
      end

      def self.grouping(requested, known, total)
        sufficient = known * 2 >= total
        return sufficient ? 'runtime' : 'filesize' if requested == 'auto'
        return requested if requested == 'filesize' || (requested == 'runtime' && sufficient)

        raise ArgumentError, 'Runtime grouping requires usable timings for at least half the selected files' if requested == 'runtime'

        raise ArgumentError, "Invalid group-by #{requested.inspect}; expected auto, filesize, or runtime"
      end

      def self.positive_integer(value)
        number = Integer(value.to_s, 10)
        raise ArgumentError, 'Expected a positive integer' unless number.positive?

        number
      end

      def self.discover(pattern)
        RuntimeLog.validate_path(pattern)
        Dir.glob(pattern).select { |file| File.file?(file) }.to_h do |file|
          [RuntimeLog.validate_path(file), File.size(file)]
        end
      end

      def self.history_for(path, files)
        return {} unless path && File.file?(path)

        RuntimeLog.read(path).slice(*files)
      rescue ArgumentError, SystemCallError => e
        warn "Ignoring unusable timing history: #{e.message}"
        {}
      end

      def initialize(directory)
        @directory = File.expand_path(directory)
        @plan = JSON.parse(File.read(File.join(@directory, 'plan.json')))
      end

      def matrix
        (1..plan.fetch('shards')).map { |shard| { shard: shard } }
      end

      def file_matrix
        groups = ParallelTests::RSpec::Runner.tests_in_groups(
          plan.fetch('sizes').keys, plan.fetch('shards'),
          { group_by: plan.fetch('group_by').to_sym, runtime_log: history_path }
        )
        groups.reject(&:empty?).map.with_index(1) { |files, shard| { shard: shard, files: files } }
      end

      def fingerprint
        Digest::SHA256.hexdigest("#{File.read(File.join(directory, 'plan.json'))}\0#{File.read(history_path)}")
      end

      def run(shard:, attempt:, directory:, env: {})
        index = validate_shard(shard)
        generation = self.class.positive_integer(attempt)
        directory = File.expand_path(directory)
        prepare_output(directory)
        code = execute_shard(index, File.join(directory, 'runtime.log'), env)
        if code.zero?
          File.write(File.join(directory, 'result.json'),
                     JSON.generate('plan' => fingerprint, 'shard' => index, 'attempt' => generation))
        end
        code
      end

      def collect(directory:, output:)
        paths = latest_results(directory)
        combined = RuntimeLog.merge(paths, files: plan.fetch('sizes').keys)
        raise ArgumentError, "No test timings were recorded#{runner.timing_hint}" if combined.empty?

        FileUtils.mkdir_p(File.dirname(output))
        RuntimeLog.write(output, combined)
        combined
      end

      private

      def validate_shard(shard)
        index = self.class.positive_integer(shard)
        raise ArgumentError, 'Shard is outside the prepared matrix' if index > plan.fetch('shards')
        raise ArgumentError, 'Selected test files or sizes changed after preparation' unless self.class.discover(plan.fetch('pattern')) == plan.fetch('sizes')

        index
      end

      def prepare_output(directory)
        FileUtils.mkdir_p(directory)
        FileUtils.rm_f(File.join(directory, 'result.json'))
        File.write(File.join(directory, 'runtime.log'), '')
      end

      def history_path
        File.join(directory, 'runtime.log')
      end

      def runner
        Runners.fetch(plan.fetch('framework', 'rspec'))
      end

      def execute_shard(index, output, env)
        files = plan.fetch('sizes').keys.map { |file| "./#{file}" }
        runner.run(shard_flags(index), files: files, options: plan.fetch('rspec_options'), output: output, env: env)
      end

      def shard_flags(index)
        ['-n', plan.fetch('shards').to_s, '--only-group', index.to_s,
         '--group-by', plan.fetch('group_by'), '--runtime-log', history_path]
      end

      def latest_results(directory)
        results = result_records(directory)
        expected = (1..plan.fetch('shards')).to_a
        raise ArgumentError, 'Incomplete or unexpected shard reports' unless results.map { |result| result.fetch('shard') }.uniq.sort == expected

        expected.map { |shard| latest_result(results.select { |result| result.fetch('shard') == shard }) }
      end

      def result_records(directory)
        Dir.glob(File.join(directory, '**/result.json')).filter_map do |path|
          result = JSON.parse(File.read(path))
          next unless result.fetch('plan') == fingerprint

          result.merge('path' => File.join(File.dirname(path), 'runtime.log'))
        end
      end

      def latest_result(results)
        results.each { |result| result['attempt'] = self.class.positive_integer(result.fetch('attempt')) }
        latest = results.max_by { |result| result.fetch('attempt') }
        raise ArgumentError, 'Duplicate reports for the same shard and attempt' if results.count { |result| result.fetch('attempt') == latest.fetch('attempt') } != 1

        latest.fetch('path')
      end
    end
  end
end
