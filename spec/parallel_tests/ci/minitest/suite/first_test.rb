# frozen_string_literal: true

require_relative 'test_helper'

class FirstTest < Minitest::Test
  def test_first
    File.open(ENV.fetch('PTCI_OBSERVED'), 'a') { |file| file.puts 'first' }
    refute_equal 'true', ENV.fetch('PTCI_FAIL', nil)
  end
end
