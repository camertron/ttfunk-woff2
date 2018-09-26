require 'yaml'

module TTFunk
  module WOFF2
    class Triplet
      class << self
        # Shamelessly ported from
        # https://github.com/google/woff2/blob/a0d0ed7da27b708c0a4e96ad7a998bddc933c06e/src/woff2_dec.cc#L125
        #
        # I have no idea how this works, but it does work. I tried to follow
        # the spec initially (https://www.w3.org/TR/WOFF2/#triplet_decoding and
        # https://www.w3.org/Submission/2008/SUBM-MTX-20080305/#TripletEncoding)
        # but the data table they present appears to either be incomplete or
        # incorrect.
        def decode(io, flags)
          flags &= 0x7F

          n_data_bytes = if flags < 84
            1
          elsif flags < 120
            2
          elsif flags < 124
            3
          else
            4
          end

          bytes = io.read(n_data_bytes).unpack('C*')

          dx = nil
          dy = nil

          if flags < 10
            dx = 0
            dy = with_sign(flags, ((flags & 14) << 7) + bytes[0]);
          elsif flags < 20
            dx = with_sign(flags, (((flags - 10) & 14) << 7) + bytes[0])
            dy = 0
          elsif flags < 84
            b0 = flags - 20
            b1 = bytes[0]
            dx = with_sign(flags, 1 + (b0 & 0x30) + (b1 >> 4))
            dy = with_sign(flags >> 1, 1 + ((b0 & 0x0C) << 2) + (b1 & 0x0F))
          elsif flags < 120
            b0 = flags - 84
            dx = with_sign(flags, 1 + ((b0 / 12) << 8) + bytes[0])
            dy = with_sign(flags >> 1, 1 + (((b0 % 12) >> 2) << 8) + bytes[1])
          elsif flags < 124
            b2 = bytes[1]
            dx = with_sign(flags, (bytes[0] << 4) + (b2 >> 4))
            dy = with_sign(flags >> 1, ((b2 & 0x0f) << 8) + bytes[2])
          else
            dx = with_sign(flags, (bytes[0] << 8) + bytes[1])
            dy = with_sign(flags >> 1, (bytes[2] << 8) + bytes[3])
          end

          [dx, dy]
        end

        private

        def with_sign(flag, baseval)
          (flag & 1) == 0 ? -baseval : baseval
        end

        def encoding_data
          @encoding_data ||= YAML.load_file(
            ::File.join(__dir__, 'triplet_encoding_data.yml')
          )
        end
      end
    end
  end
end
