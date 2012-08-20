module Sass::Tree
  class SourceRangeMapping
    attr_reader :from
    attr_reader :to
    attr_reader :source_filename
    attr_accessor :id

    def initialize(from, to, source_filename = nil)
      @from = from;
      @to = to
      @source_filename = source_filename
    end

    def to_s
      "#{from} (#{source_filename if source_filename}) -> #{to}"
    end
  end

  class SourceMapping
    attr_reader :data

    def initialize
      @data = []
    end

    def append(other)
      other.data.each {|m| @data.push(m)}
    end

    # @param from [Sass::Tree::SourceRange]
    # @param to [Sass::Tree::SourceRange]
    # @param source_filename [String]
    def add(from, to, source_filename = nil)
      @data.push(SourceRangeMapping.new(from, to, source_filename)) if (from && to)
    end

    def shift_to_ranges(line_delta, first_line_col_delta)
      if !@data.empty?
        @data[0].to.start_pos.column += first_line_col_delta
        @data[0].to.end_pos.column += first_line_col_delta
      end
      @data.each do |m|
        m.to.start_pos.line += line_delta
        m.to.end_pos.line += line_delta
      end
    end

    def shift_to_line_columns(line, col_delta)
      @data.each do |m|
        if m.to.start_pos.line == line
          m.to.start_pos.column += col_delta
        end
        if m.to.end_pos.line == line
          m.to.end_pos.column += col_delta
        end
      end
    end

    def to_s
      @data.join("\n")
    end
  end
end