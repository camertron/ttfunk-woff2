module TTFunk
  module WOFF2
    class Directory
      attr_reader :tables

      def initialize(orig_tables)
        @tables = orig_tables
      end

      def to_sfnt_directory
        offset = 0

        sfnt_dir = tables.each_with_object({}) do |(tag, table), dir|
          dir[tag] = table.merge(
            offset: offset,
            length: table[:transform_length] || table[:orig_length]
          )

          offset += table[:transform_length] || table[:orig_length]
        end

        SfntDirectory.new(sfnt_dir)
      end
    end
  end
end
