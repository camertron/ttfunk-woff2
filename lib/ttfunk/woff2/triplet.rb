require 'yaml'

module TTFunk
  module WOFF2
    class Triplet
      class << self
        def decode(io, flags)
          data = encoding_data[flags & 0x7F]
          x_negative = data.fetch(:x_sign, '+') == '-'
          y_negative = data.fetch(:y_sign, '+') == '-'

          # subtract one from byte count since one byte is for the flags
          byte_count = data[:byte_count] - 1

          coords = 0

          byte_count.times do
            coords <<= 8
            coords |= io.read(1).unpack('C').first
          end

          x_bits = data[:x_bits]
          y_bits = data[:y_bits]

          dx = coords >> ((byte_count * 8) - x_bits)
          dx &= ((1 << x_bits) - 1)

          dy = coords >> ((byte_count * 8) - x_bits - y_bits)
          dy &= ((1 << y_bits) - 1)

          dx += data.fetch(:delta_x, 0)
          dy += data.fetch(:delta_y, 0)

          dx *= -1 if x_negative
          dy *= -1 if y_negative

          [dx, dy]
        end

        private

        def encoding_data
          @encoding_data ||= YAML.load_file(
            ::File.join(__dir__, 'triplet_encoding_data.yml')
          )
        end
      end
    end
  end
end
