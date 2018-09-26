module TTFunk
  module WOFF2
    class Stream
      attr_reader :io, :offset, :fmt

      def initialize(io, offset, fmt)
        @io = StringIO.new(io.string)
        @offset = offset
        @fmt = fmt
        @io.binmode
        @io.seek(offset)
      end

      def relpos
        io.pos - offset
      end

      def get(*args)
        read(1, *args).first
      end

      def read(count, *args)
        case fmt
        when :uint8
          read_uint8(count)
        when :int16
          read_int16(count)
        when :uint16
          read_uint16(count)
        when :uint16_255
          read_uint16_255(count)
        when :uint32
          read_uint32(count)
        when :triplet
          read_triplet(count, *args)
        when :bit
          read_bit(count)
        end
      end

      def read_uint8(count)
        io.read(count).unpack('C*')
      end

      def read_int16(count)
        io.read(count * 2).unpack('n*').map do |i|
          TTFunk::BinUtils.twos_comp_to_int(i, bit_width: 16)
        end
      end

      def read_uint16(count)
        io.read(count * 2).unpack('n*')
      end

      def read_uint16_255(count)
        Array.new(count) { Utils.decode_255_ushort(io) }
      end

      def read_uint32(count)
        io.read(count * 4).unpack('N*')
      end

      def read_triplet(count, *args)
        Array.new(count) { Triplet.decode(io, *args) }
      end

      private

      # this one keeps state, so don't let outsiders call it unless
      # the stream's fmt is explicitly set to :bit
      def read_bit(count)
        Array.new(count) { read_single_bit }
      end

      def read_single_bit
        @last_byte ||= begin
          val = read_uint8(1).first
          Array.new(8) { ((val % 2) == 1).tap { val /= 2 } }.reverse
        end

        @bit_index ||= 0

        if @bit_index > 7
          @last_byte = nil
          @bit_index = 0
          read_single_bit
        else
          @last_byte[@bit_index].tap { @bit_index += 1 }
        end
      end
    end
  end
end
