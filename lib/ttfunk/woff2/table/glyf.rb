module TTFunk
  module WOFF2
    module Table
      class Glyf < TTFunk::Table
        attr_reader :glyphs

        ARG_1_AND_2_ARE_WORDS    = 0x0001
        WE_HAVE_A_SCALE          = 0x0008
        MORE_COMPONENTS          = 0x0020
        WE_HAVE_AN_X_AND_Y_SCALE = 0x0040
        WE_HAVE_A_TWO_BY_TWO     = 0x0080
        WE_HAVE_INSTRUCTIONS     = 0x0100

        SHORT_RANGE                 = (-0xFF..0xFF).freeze
        ON_CURVE_POINT              = 0x01
        X_SHORT_VECTOR              = 0x02
        Y_SHORT_VECTOR              = 0x04
        REPEAT_FLAG                 = 0x08
        X_IS_SAME_OR_POSITIVE_SHORT = 0x10
        Y_IS_SAME_OR_POSITIVE_SHORT = 0x20

        def for(glyph_id)
          # @TODO: also remove glyphs attr_reader
        end

        private

        def parse!
          reader = GlyphReader.new(io)

          @glyphs = Array.new(reader.num_glyphs) do
            n_contours = reader.n_contour_stream.get
            use_bbox = reader.bbox_bitmap.get

            glyph = if n_contours == 0
              # empty glyph
            elsif n_contours > 0
              parse_simple(reader, n_contours, use_bbox)
            else
              parse_composite(reader, n_contours, use_bbox)
            end
          end
        end

        def parse_simple(reader, n_contours, use_bbox)
          n_contour_points = reader.n_points_stream.read(n_contours)

          end_points_of_contours = []
          end_point = -1
          n_points = 0

          n_contour_points.each do |n|
            end_point += n
            end_points_of_contours << end_point
            n_points += n
          end

          flags, coords = next_glyph(reader, n_points)

          x_min, y_min, x_max, y_max = if use_bbox
            reader.bbox_stream.read(4)
          else
            min_max(coords)
          end

          instruction_length = reader.glyph_stream.read_uint16_255(1).first
          instruction_data = reader.instruction_stream.io.read(instruction_length)

          raw_glyph = pack_glyph(
            end_points_of_contours: end_points_of_contours,
            instruction_length: instruction_length,
            instruction_data: instruction_data || '',
            flags: flags,
            coords: coords
          )

          TTFunk::Table::Glyf::Simple.new(
            raw_glyph, n_contours, x_min, y_min, x_max, y_max
          )
        end

        def pack_glyph(options = {})
          result = ''.encode(Encoding::ASCII_8BIT)

          result << options.fetch(:end_points_of_contours).pack('n*')
          result << [options.fetch(:instruction_length)].pack('n')
          result << options.fetch(:instruction_data)
          result << options.fetch(:flags).pack('C*')

          options.fetch(:coords).each do |dxy|
            dxy.each do |coord|
              if SHORT_RANGE.cover?(coord)
                result << [coord.abs].pack('C')
              else
                coord = Utils.int_to_twos_comp(coord, bit_width: 16)
                result << [coord].pack('n')
              end
            end
          end

          result
        end

        def min_max(coords)
          x = 0
          y = 0

          x_min = nil
          y_min = nil
          x_max = nil
          y_max = nil

          coords.each do |dx, dy|
            x += dx
            y += dy

            unless x_min
              x_min = dx
              y_min = dy
              x_max = dx
              y_max = dy
              next
            end

            x_max = x if x > x_max
            x_min = x if x < x_min
            y_max = y if y > y_max
            y_min = y if y < y_min
          end

          [x_min || 0, y_min || 0, x_max || 0, y_max || 0]
        end

        def next_glyph(reader, n_points)
          flags = []
          coords = []
          prev_dx = nil
          prev_dy = nil

          n_points.times do |i|
            cur_flags = reader.flag_stream.get
            is_on_curve = (cur_flags & 0x80) == 0
            dx, dy = reader.glyph_stream.get(cur_flags)
            coords << [dx, dy]

            glyph_flags = 0
            glyph_flags |= 0x01 if is_on_curve

            if SHORT_RANGE.cover?(dx)
              glyph_flags |= X_SHORT_VECTOR
              glyph_flags |= X_IS_SAME_OR_POSITIVE_SHORT if dx >= 0
            elsif dx == prev_dx
              glyph_flags |= X_IS_SAME_OR_POSITIVE_SHORT
            end

            if SHORT_RANGE.cover?(dy)
              glyph_flags |= Y_SHORT_VECTOR
              glyph_flags |= Y_IS_SAME_OR_POSITIVE_SHORT if dy >= 0
            elsif dy == prev_dy
              glyph_flags | Y_IS_SAME_OR_POSITIVE_SHORT
            end

            prev_dx = dx
            prev_dy = dy

            flags << glyph_flags
          end

          [flags, coords]
        end

        def parse_composite(reader, n_contours, use_bbox)
          result = ''.encode(Encoding::ASCII_8BIT)

          unless use_bbox
            raise RuntimeError,
              'all composite glyphs must have an explicitly defined bounding box'
          end

          x_min, y_min, x_max, y_max = reader.bbox_stream.read(4)
          result << [n_contours, x_min, y_min, x_max, y_max].pack('n*')

          have_instrs = false
          all_flags = []

          loop do
            argument_length = 2  # for glyph index
            flags = reader.composite_stream.read_uint16(1).first
            all_flags << flags
            have_instrs ||= (flags & WE_HAVE_INSTRUCTIONS) != 0
            argument_length += (flags & ARG_1_AND_2_ARE_WORDS == 0) ? 2 : 4

            if flags & WE_HAVE_A_TWO_BY_TWO != 0
              argument_length += 8
            elsif flags & WE_HAVE_AN_X_AND_Y_SCALE != 0
              argument_length += 4
            elsif flags & WE_HAVE_A_SCALE != 0
              argument_length += 2
            end

            result << [flags].pack('n')
            result << reader.composite_stream.io.read(argument_length)

            break if flags & MORE_COMPONENTS == 0
          end

          if have_instrs
            instruction_length = reader.glyph_stream.read_uint16_255(1).first
            result << reader.instruction_stream.io.read(instruction_length)
          end

          TTFunk::Table::Glyf::Compound.new(
            result, x_min, y_min, x_max, y_max
          )
        end
      end
    end
  end
end
