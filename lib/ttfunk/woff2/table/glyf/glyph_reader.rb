module TTFunk
  module WOFF2
    module Table
      class Glyf < TTFunk::Table
        class GlyphReader
          attr_reader :version
          attr_reader :num_glyphs
          attr_reader :index_format
          attr_reader :n_contour_stream_size
          attr_reader :n_points_stream_size
          attr_reader :flag_stream_size
          attr_reader :glyph_stream_size
          attr_reader :composite_stream_size
          attr_reader :bbox_stream_size
          attr_reader :instruction_stream_size

          # streams
          attr_reader :n_contour_stream
          attr_reader :n_points_stream
          attr_reader :flag_stream
          attr_reader :glyph_stream
          attr_reader :composite_stream
          attr_reader :bbox_bitmap
          attr_reader :bbox_stream
          attr_reader :instruction_stream

          def initialize(io)
            @version, @num_glyphs, @index_format, @n_contour_stream_size,
              @n_points_stream_size, @flag_stream_size, @glyph_stream_size,
              @composite_stream_size, @bbox_stream_size, @instruction_stream_size =
              io.read(36).unpack('Nn2N7')

            pos = io.pos

            @n_contour_stream = Stream.new(io, pos, :int16)
            pos += n_contour_stream_size

            @n_points_stream = Stream.new(io, pos, :uint16_255)
            pos += n_points_stream_size

            @flag_stream = Stream.new(io, pos, :uint8)
            pos += flag_stream_size

            @glyph_stream = Stream.new(io, pos, :triplet)
            pos += glyph_stream_size

            @composite_stream = Stream.new(io, pos, :triplet)
            pos += composite_stream_size

            @bbox_bitmap = Stream.new(io, pos, :bit)
            pos += ((num_glyphs + 31) >> 5) << 2

            @bbox_stream = Stream.new(io, pos, :int16)
            pos += bbox_stream_size

            @instruction_stream = Stream.new(io, pos, :uint8)
          end
        end
      end
    end
  end
end
