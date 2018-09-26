module TTFunk
  module WOFF2
    module Table
      class Glyf < TTFunk::Table
        class Simple
          # bounding box
          attr_accessor :x_min
          attr_accessor :x_max
          attr_accessor :y_min
          attr_accessor :y_max

          attr_accessor :contours

          attr_accessor :instruction_data

          def initialize
            @x_min = 0
            @x_max = 0
            @y_min = 0
            @y_max = 0
            @contours = []
          end
        end
      end
    end
  end
end
