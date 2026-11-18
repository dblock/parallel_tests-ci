# frozen_string_literal: true

require 'pathname'

module ParallelTests
  module CI
    # Reads the upstream file:seconds format without accepting ambiguous measurements.
    module RuntimeLog
      module_function

      def validate_path(path)
        unless path.is_a?(String) && path.valid_encoding? && path.match?(/\A[^\\\r\n\0]+\z/) &&
               !Pathname.new(path).absolute? && !path.split('/').include?('..')
          raise ArgumentError, "Expected a relative repository path: #{path.inspect}"
        end

        Pathname.new(path).cleanpath.to_s
      end

      def read(path)
        File.foreach(path).each_with_object({}) do |line, entries|
          file, separator, seconds = line.chomp.rpartition(':')
          raise ArgumentError, "Invalid runtime entry: #{line.inspect}" if separator.empty?

          file = validate_path(file)
          raise ArgumentError, "Duplicate runtime for #{file}" if entries.key?(file)

          entries[file] = parse_duration(seconds, file)
        end
      end

      def parse_duration(value, file)
        duration = Float(value)
        raise ArgumentError, "Invalid duration for #{file}" unless duration.finite? && !duration.negative?

        duration
      end

      def write(path, entries)
        File.write(path, entries.sort.map { |file, seconds| "#{file}:#{seconds}\n" }.join)
      end

      def merge(paths, files:)
        paths.each_with_object({}) do |path, combined|
          read(path).each do |file, seconds|
            raise ArgumentError, "Unexpected measured file: #{file}" unless files.include?(file)
            raise ArgumentError, "Duplicate runtime for #{file}" if combined.key?(file)

            combined[file] = seconds
          end
        end
      end
    end
  end
end
