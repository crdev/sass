module Sass::Tree
  class SourcePosition
    # The line of the document associated with the position (zero-based).
    #
    # @return [Fixnum]
    attr_accessor :line

    # The column in the line of the document associated with the position (zero-based).
    #
    # @return [Fixnum]
    attr_accessor :column

    # @param line [Fixnum] The source line
    # @param column [Fixnum] The source column
    def initialize(line, column)
      @line = line
      @column = column
    end

    def shift(line_delta, column_delta = 0)
      @line += line_delta
      @column += column_delta
    end

    def to_s
      "(#{@line}:#{@column})"
    end
  end
end
