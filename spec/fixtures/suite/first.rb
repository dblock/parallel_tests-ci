# frozen_string_literal: true

RSpec.describe 'First Fixture' do
  it 'records its execution' do
    File.open(ENV.fetch('PTCI_OBSERVED', 'observed.txt'), 'a') { |file| file.puts 'first' }
  end
end
