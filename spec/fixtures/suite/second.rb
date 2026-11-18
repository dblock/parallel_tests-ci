# frozen_string_literal: true

RSpec.describe 'Second Fixture' do
  it 'records its execution or fails when requested' do
    raise 'Requested fixture failure' if ENV['PTCI_FAIL'] == 'true'

    File.open(ENV.fetch('PTCI_OBSERVED', 'observed.txt'), 'a') { |file| file.puts 'second' }
  end
end
