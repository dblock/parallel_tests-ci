# frozen_string_literal: true

module ParallelTests
  module CI
    # Reads the upstream file:seconds format without accepting ambiguous measurements.
    module RuntimeLog
      module_function

      # Rejects absolute, drive-prefixed, backslash, and control-character paths on every platform.
      UNSAFE_PATH = %r{\A(?:/|[A-Za-z]:)|[\\\r\n\0]}

      # Normalizes string segments, since Windows paths would read a colon-containing name as a drive.
      def validate_path(path)
        segments = path.split('/').reject { |segment| segment.empty? || segment == '.' } if safe_string?(path)
        unless segments&.any? && !segments.include?('..')
          raise ArgumentError, "Expected a relative repository path: #{path.inspect}"
        end

        segments.join('/')
      end

      def safe_string?(path)
        path.is_a?(String) && path.valid_encoding? && !path.match?(UNSAFE_PATH)
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
