# frozen_string_literal: true

require 'open3'
require 'uri'
require 'parallel_tests/ci'

module ParallelTests
  module CI
    # Internal entry points used by the reusable workflow, not a consumer CLI.
    module GitHub
      DIRECTORY = 'tmp/parallel_tests_ci'
      class Error < StandardError; end

      module_function

      def event
        JSON.parse(File.read(ENV.fetch('GITHUB_EVENT_PATH')))
      end

      def prefix(value)
        unless value.match?(/\A[a-zA-Z0-9][a-zA-Z0-9_-]*\z/)
          raise ArgumentError, 'Artifact prefix must contain only letters, numbers, underscores, and hyphens'
        end

        value
      end

      def api(path, paginate: false)
        arguments = ['gh', 'api', path]
        arguments.push('--paginate', '--slurp') if paginate
        output, error, status = Open3.capture3(*arguments)
        raise Error, error unless status.success?

        JSON.parse(output)
      end

      def find_history(inputs:)
        repository = ENV.fetch('GITHUB_REPOSITORY')
        artifact_prefix = prefix(inputs.fetch('artifact-prefix'))
        successful_runs(repository).each do |run|
          artifact = history_artifact(repository, run.fetch('id'), artifact_prefix: artifact_prefix)
          next unless artifact

          outputs(history_run: run.fetch('id'), history_artifact: artifact.fetch('id'))
          break
        end
      rescue Error, JSON::ParserError, SystemCallError => e
        warn "Timing history unavailable; using file sizes: #{e.message}"
      end

      def successful_runs(repository)
        current = api("repos/#{repository}/actions/runs/#{ENV.fetch('GITHUB_RUN_ID')}")
        branch = URI.encode_www_form_component(event.fetch('repository').fetch('default_branch'))
        path = "repos/#{repository}/actions/workflows/#{current.fetch('workflow_id')}/runs"
        api("#{path}?branch=#{branch}&event=push&status=success&per_page=20")
          .fetch('workflow_runs').select { |run| trusted_run?(run, repository) }
      end

      def history_artifact(repository, id, artifact_prefix:)
        pages = api("repos/#{repository}/actions/runs/#{id}/artifacts?per_page=100", paginate: true)
        pages.flat_map { |page| page.fetch('artifacts') }.find do |entry|
          entry.fetch('name') == "#{artifact_prefix}-runtimes" && !entry.fetch('expired')
        end
      end

      def trusted_run?(run, repository)
        run.fetch('event') == 'push' && run.fetch('conclusion') == 'success' &&
          run.fetch('head_branch') == event.fetch('repository').fetch('default_branch') &&
          run.dig('head_repository', 'full_name') == repository
      end

      def prepare(inputs:)
        run = Run.prepare(directory: "#{DIRECTORY}/plan", history: "#{DIRECTORY}/history/runtime.log",
                          pattern: inputs.fetch('pattern'), shards: inputs.fetch('shards'),
                          rspec_options: JSON.parse(inputs.fetch('rspec-options')))
        outputs(matrix: JSON.generate(worker_matrix(run, inputs: inputs)),
                artifact: "#{prefix(inputs.fetch('artifact-prefix'))}-plan-#{ENV.fetch('GITHUB_RUN_ATTEMPT')}")
        puts "Prepared #{run.plan.fetch('shards')} shards using #{run.plan.fetch('group_by')} grouping."
      end

      def worker_matrix(run, inputs:)
        template = inputs.fetch('worker-name', '')
        template = '{shard.number} of {shard.count}' if template.empty?
        values = { 'shard.count' => run.plan.fetch('shards').to_s, 'plan.group_by' => run.plan.fetch('group_by') }
        run.matrix.map do |entry|
          entry.merge(name: render_template(template, values.merge('shard.number' => entry.fetch(:shard).to_s)))
        end
      end

      def render_template(template, values)
        template.gsub(/\{([^{}]*)\}|[{}]/) do |token|
          key = Regexp.last_match(1)
          values.fetch(key) do
            raise ArgumentError, "Unknown or malformed template placeholder: #{token}"
          end
        end
      end

      def run(inputs:, shard:)
        attempt = ENV.fetch('GITHUB_RUN_ATTEMPT')
        code = Run.new("#{DIRECTORY}/plan").run(shard: shard, attempt: attempt, directory: "#{DIRECTORY}/result")
        outputs(artifact: "#{prefix(inputs.fetch('artifact-prefix'))}-shard-#{shard}-#{attempt}") if code.zero?
        exit(code)
      end

      def collect
        Run.new("#{DIRECTORY}/plan").collect(directory: "#{DIRECTORY}/results",
                                             output: "#{DIRECTORY}/baseline/runtime.log")
      end

      def outputs(values)
        File.open(ENV.fetch('GITHUB_OUTPUT'), 'a') do |file|
          values.each { |key, value| file.puts "#{key}=#{value}" }
        end
      end
    end
  end
end
