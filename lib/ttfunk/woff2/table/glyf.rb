module TTFunk
  module WOFF2
    module Table
      class Glyf < TTFunk::Table
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
          @glyphs[glyph_id]
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

          flags, x_deltas, y_deltas = next_glyph(reader, n_points)

          if use_bbox
            x_min, y_min, x_max, y_max = reader.bbox_stream.read(4)
          else
            x_min, x_max = delta_min_max(x_deltas)
            y_min, y_max = delta_min_max(y_deltas)
          end

          instruction_length = reader.glyph_stream.read_uint16_255(1).first
          instruction_data = reader.instruction_stream.io.read(instruction_length)

          raw_glyph = pack_glyph(
            end_points_of_contours: end_points_of_contours,
            instruction_length: instruction_length,
            instruction_data: instruction_data || '',
            flags: flags,
            x_deltas: x_deltas,
            y_deltas: y_deltas,
            n_contours: n_contours,
            n_points: n_points,
            x_min: x_min,
            y_min: y_min,
            x_max: x_max,
            y_max: y_max
          )

          TTFunk::Table::Glyf::Simple.new(
            raw_glyph, n_contours, x_min, y_min, x_max, y_max
          )
        end

        def pack_glyph(options = {})
          result = ''.encode(Encoding::ASCII_8BIT)

          result << [
            options.fetch(:n_contours),
            options.fetch(:x_min),
            options.fetch(:y_min),
            options.fetch(:x_max),
            options.fetch(:y_max)
          ].pack('n*')

          result << options.fetch(:end_points_of_contours).pack('n*')
          result << [options.fetch(:instruction_length)].pack('n')
          result << options.fetch(:instruction_data)
          result << options.fetch(:flags).pack('C*')

          options.fetch(:x_deltas).each do |x_delta|
            result << pack_delta(x_delta)
          end

          options.fetch(:y_deltas).each do |y_delta|
            result << pack_delta(y_delta)
          end

          result
        end

        def pack_delta(da)
          if SHORT_RANGE.cover?(da)
            [da.abs].pack('C')
          else
            da = Utils.int_to_twos_comp(da, bit_width: 16)
            [da].pack('n')
          end
        end

        def delta_min_max(deltas)
          a = 0

          a_min = nil
          a_max = nil

          deltas.each do |da|
            a += da

            unless a_min
              a_min = da
              a_max = da
              next
            end

            a_max = a if a > a_max
            a_min = a if a < a_min
          end

          [a_min || 0, a_max || 0]
        end

        def next_glyph(reader, n_points)
          flags = []
          x_deltas = []
          y_deltas = []
          prev_dx = nil
          prev_dy = nil
          last_flags = nil

          n_points.times do |i|
            cur_flags = reader.flag_stream.get
            is_on_curve = (cur_flags & 0x80) == 0
            dx, dy = reader.glyph_stream.get(cur_flags)
            x_deltas << dx
            y_deltas << dy

            glyph_flags = 0
            glyph_flags |= 0x01 if is_on_curve

            # if dx == 0
            #   glyph_flags |= X_IS_SAME_OR_POSITIVE_SHORT
            if SHORT_RANGE.cover?(dx)
              glyph_flags |= X_SHORT_VECTOR | (dx > 0 ? X_IS_SAME_OR_POSITIVE_SHORT : 0)
            end

            # if dy == 0
            #   glyph_flags |= X_SHORT_VECTOR
            if SHORT_RANGE.cover?(dy)
              glyph_flags |= Y_SHORT_VECTOR | (dy > 0 ? Y_IS_SAME_OR_POSITIVE_SHORT : 0)
            end

            # if glyph_flags == last_flags && repeat_count != 255
            #   # @TODO
            #   dst[flag_offset - 1] |= kGlyfRepeat;
            #   repeat_count++;
            # end

            prev_dx = dx
            prev_dy = dy

            flags << glyph_flags
            last_flags = glyph_flags
          end

          [flags, x_deltas, y_deltas]
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
