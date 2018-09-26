module TTFunk
  module WOFF2
    class SfntDirectory
      attr_reader :tables

      def initialize(tables)
        @tables = tables
      end
    end
  end
end
