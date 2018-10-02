module TTFunk
  module WOFF2
    class SfntDirectory
      SCALER_TYPE_TRUETYPE = 0x00010000
      SCALER_TYPE_CFF = 0x4F54544F  # OTTO

      attr_reader :tables

      def initialize(tables)
        @tables = tables
      end

      def scaler_type
        return SCALER_TYPE_CFF if tables.include?(TTFunk::Table::Cff::TAG)
        SCALER_TYPE_TRUETYPE
      end
    end
  end
end
