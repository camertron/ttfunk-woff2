module TTFunk
  module WOFF2
    module Utils
      ONE_MORE_BYTE_CODE_1 = 255
      ONE_MORE_BYTE_CODE_2 = 254
      WORD_CODE = 253
      LOWEST_UCODE = 253

      def decode_255_ushort(io)
        code = read_byte(io)

        if code == WORD_CODE
          value = read_byte(io)
          value <<= 8
          value &= 0xFF00
          value2 = read_byte(io)
          value | value2 & 0x00FF
        elsif code == ONE_MORE_BYTE_CODE_1
          read_byte(io) + LOWEST_UCODE
        elsif code == ONE_MORE_BYTE_CODE_2
          read_byte(io) + LOWEST_UCODE * 2
        else
          code
        end
      end

      def encode_255_ushort(num)
        if num > (2**16) - 1 || num < 0
          raise ArgumentError, "#{num} is out of uint16 range"
        end

        bytes = if num < 253
          [num]
        elsif num < 509
          [ONE_MORE_BYTE_CODE_1, num - LOWEST_UCODE]
        elsif num < 762
          [ONE_MORE_BYTE_CODE_2, num - LOWEST_UCODE * 2]
        else
          [WORD_CODE, num >> 8, num & 0x00FF]
        end

        bytes.pack('C*')
      end

      def decode_uint_base_128(io)
        accum = 0

        5.times do |i|
          data_byte = read_byte(io)

          if i == 0 && data_byte == 0x80
            raise RuntimeError, 'base 128-encoded uints must not have leading zeroes'
          end

          # if any of top 7 bits are set then << 7 would overflow
          if accum & 0xFE000000 != 0
            raise RuntimeError, 'base 128-encoded uint overflow'
          end

          accum = (accum << 7) | (data_byte & 0x7F)

          return accum if data_byte & 0x80 == 0
        end

        raise RuntimeError, 'base 128-encoded uint exceeded 5 bytes'
      end

      def encode_uint_base_128(num)
        if num > (2**32) - 1 || num < 0
          raise ArgumentError, "#{num} is out of uint32 range"
        end

        # first byte should have MSB set to 0
        bytes = [num & 0x7F]
        num >>= 7

        while num > 0
          # all bytes except the least significant should have their
          # MSBs set to 1
          bytes.unshift((num & 0x7F) | 0x80)
          num >>= 7
        end

        bytes.pack('C*')
      end

      def int_to_twos_comp(int, bit_width:)
        return int if int >= 0

        # xor flips the bits
        (int.abs ^ ((1 << bit_width) - 1)) + 1
      end

      def checksum(data)
        align(data, 4).unpack('N*').reduce(0, :+) & 0xFFFF_FFFF
      end

      def align(data, width)
        if data.length % width > 0
          data + "\0" * (width - data.length % width)
        else
          data
        end
      end

      private

      def read_byte(io)
        io.read(1).unpack('C').first
      end
    end

    Utils.extend(Utils)
  end
end
