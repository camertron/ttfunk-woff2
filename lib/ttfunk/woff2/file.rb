require 'brotli'
require 'ttfunk'

module TTFunk
  module WOFF2
    class File < ::TTFunk::File
      ARBITRARY_TAG_INDEX = 63
      TAG_MAP = {
        0  => 'cmap', 1  => 'head', 2  => 'hhea', 3  => 'hmtx', 4  => 'maxp',
        5  => 'name', 6  => 'OS/2', 7  => 'post', 8  => 'cvt ', 9  => 'fpgm',
        10 => 'glyf', 11 => 'loca', 12 => 'prep', 13 => 'CFF ', 14 => 'VORG',
        15 => 'EBDT', 16 => 'EBLC', 17 => 'gasp', 18 => 'hdmx', 19 => 'kern',
        20 => 'LTSH', 21 => 'PCLT', 22 => 'VDMX', 23 => 'vhea', 24 => 'vmtx',
        25 => 'BASE', 26 => 'GDEF', 27 => 'GPOS', 28 => 'GSUB', 29 => 'EBSC',
        30 => 'JSTF', 31 => 'MATH', 32 => 'CBDT', 33 => 'CBLC', 34 => 'COLR',
        35 => 'CPAL', 36 => 'SVG ', 37 => 'sbix', 38 => 'acnt', 39 => 'avar',
        40 => 'bdat', 41 => 'bloc', 42 => 'bsln', 43 => 'cvar', 44 => 'fdsc',
        45 => 'feat', 46 => 'fmtx', 47 => 'fvar', 48 => 'gvar', 49 => 'hsty',
        50 => 'just', 51 => 'lcar', 52 => 'mort', 53 => 'morx', 54 => 'opbd',
        55 => 'prop', 56 => 'trak', 57 => 'Zapf', 58 => 'Silf', 59 => 'Glat',
        60 => 'Gloc', 61 => 'Feat', 62 => 'Sill'
      }.freeze

      attr_reader :woff2_header

      # override these since we're inheriting from TTFunk::File
      class << self
        def from_dfont(*args)
          raise NotImplementedError, 'WOFF2s are not DFonts'
        end

        def from_ttc(*args)
          raise NotImplementedError, 'WOFF2s are not font collections'
        end

        def open(io_or_path)
          io = StringIO.new(verify_and_open(io_or_path).read)
          woff2_header = Header.new(io)
          woff2_directory = parse_directory(woff2_header, io)

          if woff2_header.collection?
            raise RuntimeError, 'TTF collections are currently not supported'
          end

          # skip byte alignment padding
          io.read(4 - io.pos % 4) unless io.pos % 4 == 0
          sfnt = Brotli.inflate(io.read(woff2_header.total_compressed_size))

          new(woff2_header, woff2_directory, sfnt)
        end

        private

        def parse_directory(woff2_header, io)
          tables = {}

          woff2_header.num_tables.times do
            flags = io.read(1).unpack('C').first
            tag_index = flags & 0x3F
            trans_version = flags >> 6

            tag = if tag_index == ARBITRARY_TAG_INDEX
              io.read(4).unpack('a*').first
            else
              TAG_MAP[tag_index]
            end

            orig_length = Utils.decode_uint_base_128(io)

            unless null_transform?(tag, trans_version)
              transform_length = Utils.decode_uint_base_128(io)
            end

            tables[tag] = {
              tag: tag,
              trans_version: trans_version,
              orig_length: orig_length,
              transform_length: transform_length
            }
          end

          Directory.new(tables)
        end

        private

        # For all tables in a font, except for 'glyf' and 'loca' tables,
        # transformation version 0 indicates the null transform where the
        # original table data is passed directly to the Brotli compressor
        # for inclusion in the compressed data stream. For 'glyf' and
        # 'loca' tables, transformation version 3 indicates the null
        # transform.
        def null_transform?(tag, trans_version)
          if tag == 'glyf' || tag == 'loca'
            trans_version == 3
          else
            trans_version == 0
          end
        end
      end

      attr_reader :woff2_header

      def initialize(woff2_header, woff2_directory, sfnt_contents)
        @woff2_header = woff2_header
        @directory = woff2_directory.to_sfnt_directory
        @contents = StringIO.new(sfnt_contents)
        contents.binmode
      end

      def glyph_outlines
        @glyph_outlines ||= TTFunk::WOFF2::Table::Glyf.new(self)
      end
    end
  end
end
