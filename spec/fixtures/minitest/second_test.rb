# frozen_string_literal: true

require_relative 'test_helper'

class SecondTest < Minitest::Test
  def test_second
    File.open(ENV.fetch('PTCI_OBSERVED'), 'a') { |file| file.puts 'second' }
    assert ENV.key?('TEST_ENV_NUMBER')
  end
end
