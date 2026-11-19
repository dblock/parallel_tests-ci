# frozen_string_literal: true

require 'ruby-gem-release/version/ruby_constant'

# Updates published README references while advancing the development version.
class ReleaseVersion < RubyGemRelease::Version::RubyConstant
  def increment!(part: :patch, from: read)
    original = File.read('README.md')
    updated = original.gsub(%r{(dblock/parallel_tests-ci(?:/\.github/workflows/[\w.-]+)?@v)\d+\.\d+\.\d+(?![\w.+-])}) do
      "#{Regexp.last_match(1)}#{from}"
    end
    updated = updated.gsub(/(gem ['"]parallel_tests-ci['"], ['"])\d+\.\d+\.\d+(['"])/) do
      "#{Regexp.last_match(1)}#{from}#{Regexp.last_match(2)}"
    end
    next_version = super
    File.write('README.md', updated) unless original == updated
    next_version
  end
end
