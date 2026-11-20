# frozen_string_literal: true

require 'yaml'

RSpec.describe 'Framework workflow contract' do # rubocop:disable RSpec/DescribeClass -- This spec checks workflow YAML, not a Ruby class.
  def workflow(name)
    YAML.safe_load_file(File.expand_path("../../../.github/workflows/#{name}.yml", __dir__), aliases: true)
  end

  def workflow_call(document)
    # Psych treats the unquoted YAML key `on` as a boolean.
    document.fetch('on') { document.fetch(true) }.fetch('workflow_call')
  end

  def input_contract(inputs)
    inputs.transform_values { |input| input.slice('type', 'default', 'required') }
  end

  let(:shared_call) { workflow_call(workflow('shards')) }

  {
    'rspec' => { 'pattern' => 'spec/**/*_spec.rb', 'artifact-prefix' => 'parallel-tests-ci' },
    'minitest' => { 'pattern' => 'test/**/*_test.rb', 'artifact-prefix' => 'parallel-tests-ci' }
  }.each do |framework, defaults|
    context "with #{framework}" do
      let(:wrapper) { workflow(framework) }
      let(:call) { workflow_call(wrapper) }
      let(:job) { wrapper.fetch('jobs').fetch('shards') }
      let(:inputs) { call.fetch('inputs') }

      it 'exposes the shared input contract with framework-specific defaults' do
        expected = input_contract(shared_call.fetch('inputs')).except('framework')
        defaults.each do |name, default|
          expected[name] = expected.fetch(name).except('required').merge('default' => default)
        end

        expect(input_contract(inputs)).to eq(expected)
      end

      it 'forwards every public input under the same name' do
        expected = inputs.keys.to_h { |name| [name, "${{ inputs.#{name} }}"] }

        expect(job.fetch('with')).to eq(expected.merge('framework' => framework))
      end

      it 'calls the shared workflow' do
        expect(job.fetch('uses')).to eq('./.github/workflows/shards.yml')
      end

      it 'declares the same secrets as the shared workflow' do
        expect(call.fetch('secrets')).to eq(shared_call.fetch('secrets'))
      end

      it 'forwards the declared secrets' do
        expected = call.fetch('secrets').keys.to_h { |name| [name, "${{ secrets.#{name} }}"] }

        expect(job.fetch('secrets')).to eq(expected)
      end
    end
  end
end
