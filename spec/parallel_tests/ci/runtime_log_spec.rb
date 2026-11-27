# frozen_string_literal: true

RSpec.describe ParallelTests::CI::RuntimeLog, :aggregate_failures do
  include_context 'with a temporary project'

  it 'reads colon-containing paths, normalizes relative paths, and retains zero durations' do
    File.write('runtime.log', "./spec/a:b_spec.rb:0\nspec//./other_spec.rb:1.25\n")
    expect(described_class.read('runtime.log')).to eq('spec/a:b_spec.rb' => 0.0, 'spec/other_spec.rb' => 1.25)
  end

  ['missing separator', 'spec/a.rb:no', 'spec/a.rb:-1', 'spec/a.rb:1e999', '/outside.rb:1',
   'C:/outside.rb:1', 'c:outside.rb:1', './.:1', '../outside.rb:1', "spec/a.rb:1\n./spec/a.rb:2"].each do |contents|
    it "rejects unusable measurements #{contents.inspect}" do
      File.write('runtime.log', contents)
      expect { described_class.read('runtime.log') }.to raise_error(ArgumentError)
    end
  end

  ["bad\0path", "bad\npath", 'bad\\path', '', nil, "bad\xFF".b.force_encoding('UTF-8')].each do |path|
    it "rejects unsafe paths #{path.inspect}" do
      expect { described_class.validate_path(path) }.to raise_error(ArgumentError)
    end
  end

  it 'writes sorted upstream-compatible reports' do
    described_class.write('runtime.log', 'spec/z.rb' => 2.0, 'spec/a.rb' => 0.0)
    expect(File.read('runtime.log')).to eq("spec/a.rb:0.0\nspec/z.rb:2.0\n")
  end

  it 'accepts empty shard logs' do
    File.write('empty.log', '')
    expect(described_class.read('empty.log')).to eq({})
  end

  it 'rejects duplicate measurements across reports' do
    File.write('first.log', "spec/a.rb:1\n")
    File.write('second.log', "spec/a.rb:2\n")
    expect { described_class.merge(%w[first.log second.log], files: ['spec/a.rb']) }
      .to raise_error(ArgumentError, /Duplicate/)
  end

  it 'rejects measured files outside the selected suite' do
    File.write('first.log', "spec/a.rb:1\n")
    expect { described_class.merge(['first.log'], files: ['spec/b.rb']) }
      .to raise_error(ArgumentError, /Unexpected/)
  end
end
