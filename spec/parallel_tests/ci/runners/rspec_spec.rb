# frozen_string_literal: true

RSpec.describe ParallelTests::CI::Runners::RSpec do
  let(:files) { Array.new(400) { |index| "./spec/#{'nested/' * 12}example_#{index}_spec.rb" } }

  it 'rejects Windows command lines over the process creation limit before spawning', :aggregate_failures do
    allow(Gem).to receive(:win_platform?).and_return(true)
    allow(Process).to receive(:spawn)
    expect { described_class.new.run([], files: files, options: [], output: 'runtime.log', env: {}) }
      .to raise_error(ArgumentError, /command for 400 files is \d+ characters, over the Windows limit of 32767/)
    expect(Process).not_to have_received(:spawn)
  end

  it 'does not limit command lines on other platforms' do
    allow(Gem).to receive(:win_platform?).and_return(false)
    allow(Process).to receive_messages(spawn: 42, wait2: [42, instance_double(Process::Status, exitstatus: 0)])
    expect(described_class.new.run([], files: files, options: [], output: 'runtime.log', env: {})).to eq(0)
  end
end
