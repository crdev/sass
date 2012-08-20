require "sass/engine"
require "base64"

module Sass::Tree
  class JSONObject
    def initialize
      @data = {}
      @key_order = []
    end

    def put(key, value)
      @key_order.push(key) unless @data.has_key?(key)
      @data[key] = value
    end

    def dump
      result = []
      @key_order.each do |k|
        result.push("\"#{escape_quotes(k)}\":#{dump_value(@data[k])}")
      end
      "{#{result.join(", ")}}"
    end

    private

    def is_boolean?(value)
      value.is_a?(TrueClass) || value.is_a?(FalseClass)
    end

    def escape_quotes(s)
      s.sub(/\"/, "\\\"")
    end

    def dump_value(v)
      case v.class.name
      when "Fixnum"
        v
      when "String"
        "\"#{escape_quotes(v)}\""
      when JSONObject
        return v.dump
      when "Array"
        result = []
        v.each {|x| result.push(dump_value(x))}
        return "[" + result.join(",") + "]"
      when "NilClass"
        "null"
      else
        "#{v}" if is_boolean?(v)
         "\"\"" # unknown type maps to an empty string
      end          
    end
  end

  class SourcemapBuilder

    VLQ_BASE_SHIFT = 5
    VLQ_BASE = 1 << VLQ_BASE_SHIFT
    VLQ_BASE_MASK = VLQ_BASE - 1
    VLQ_CONTINUATION_BIT = VLQ_BASE

    BASE64_DIGITS = ('A'..'Z').to_a.concat(('a'..'z').to_a).concat(('0'..'9').to_a).concat(['+', '/'])
    BASE64_DIGIT_MAP = begin
      map = {}
      BASE64_DIGITS.each_index {|i| map[BASE64_DIGITS[i]] = i}
      map
    end

    def initialize
      @offset_position = SourcePosition.new(0, 0)
    end

    def set_offset_position(position)
      @offset_position = position
    end

    def for_range_boundaries(range)
      adjusted_range = adjust_target_range(range)
      yield(adjusted_range.start_pos)
      yield(adjusted_range.end_pos)
    end

    def build_sourcemap(source_mapping, target_filename, source_root = "")
      puts(source_mapping)
      last_mapping = nil
      max_line = 0

      result = JSONObject.new
      result.put("version", "3")

      source_filename_to_id = {}
      id_to_source_filename = {}
      filename_id = 0
      line_data = []
      segment_data_for_line = []

      previous_target_line = 0
      previous_target_column = nil
      previous_source_line = nil
      previous_source_column = nil
      previous_source_file_id = nil

      source_mapping.data.each do |m|
        current_source_id = source_filename_to_id[m.source_filename]
        if !current_source_id
          source_filename_to_id[m.source_filename] = filename_id
          id_to_source_filename[filename_id] = m.source_filename
          current_source_id = filename_id
          filename_id += 1
        end

        for_range_boundaries(m.to) do |source_pos|
          previous_target_column = nil if source_pos.line != previous_target_line
          new_target_line = previous_target_line != source_pos.line
  
          segment = ""
          adjusted_target_start_column = source_pos.column
          adjusted_target_start_column -= previous_target_column if previous_target_column
          segment << encode_vlq(adjusted_target_start_column)
          
          segment << encode_vlq(current_source_id - (previous_source_file_id || 0))
          previous_source_file_id = current_source_id
  
          adjusted_source_start_line = m.from.start_pos.line
          adjusted_source_start_line -= previous_source_line if previous_source_line
          previous_source_line = m.from.start_pos.line
          segment << encode_vlq(adjusted_source_start_line)
  
          adjusted_source_start_column = m.from.start_pos.column
          adjusted_source_start_column -= previous_source_column if previous_source_column
          previous_source_column = m.from.start_pos.column
          segment << encode_vlq(adjusted_source_start_column)
  
          if new_target_line
            line_data.push(segment_data_for_line.join(","))
            for i in (previous_target_line...source_pos.line - 1)
              line_data.push("")
            end
            segment_data_for_line = [segment]
          else
            segment_data_for_line.push(segment)
          end
  
          previous_target_column = source_pos.column
          previous_target_line = source_pos.line
        end
        #max_line = target_range.end_pos.line
      end
      line_data.push(segment_data_for_line.join(","))
      result.put("mappings", line_data.join(";"))

      source_names = []
      (0...filename_id).each {|id| source_names.push(id_to_source_filename[id].gsub(/\.\//, "") || "")}
      result.put("sources", source_names)
      #result.put("lineCount", (max_line + 1).to_s)
      result.put("sourceRoot", source_root)
      result.put("file", target_filename.gsub(/\"/, "\\\""))

      result
    end

    private

    def adjust_target_range(range)
      return range if @offset_position.line == 0 && @offset_position.column == 0
      start_pos = range.start_pos
      end_pos = range.end_pos
      offset_line = @offset_position.line
      start_offset_column = @offset_position.column
      end_offset_column = @offset_position.column
      start_offset_column = 0 if start_pos.line > 0
      end_offset_column = 0 if end_pos.line > 0

      start_pos = SourcePosition.new(start_pos.line + offset_line, start_pos.column + start_offset_column)
      end_pos = SourcePosition.new(end_pos.line + offset_line, end_pos.column + end_offset_column)
      SourceRange.new(start_pos, end_pos)    
    end

    def to_base64(number)
      return [0] if number.zero?
      number = number.abs
      [].tap do |digits|
        while number > 0
          digits.unshift number % 64
          number /= 64
        end
      end
      digits.join()
    end
        
    def encode_vlq(value)
      if value < 0
        value = ((-value) << 1) | 1
      else
        value <<= 1 
      end

      result = String.new
      begin
        digit = value & VLQ_BASE_MASK
        value >>= VLQ_BASE_SHIFT
        if value > 0
          digit |= VLQ_CONTINUATION_BIT
        end
        result << BASE64_DIGITS[digit]
      end while value > 0
      result
    end

    def decode_vlq(value)
      result = []
      resultValue = 0 
      shift = 0
      continuation = nil
      value.split("").each do |c|
        digit = BASE64_DIGIT_MAP[c]
        continuation = digit & VLQ_CONTINUATION_BIT
        digit &= VLQ_BASE_MASK
        resultValue += digit << shift
        shift += VLQ_BASE_SHIFT
        if continuation == 0
          negate = (resultValue & 1) == 1
          resultValue >>= 1 
          result.push(negate ? -resultValue : resultValue)
          resultValue = 0
          shift = 0
          continuation = nil
        end
      end
      # assert continuation == 0
      result
    end
  end
end