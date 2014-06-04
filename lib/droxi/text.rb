# Module containing text-manipulation methods.
module Text

  # The assumed width of the terminal if GNU Readline can't retrieve it.
  DEFAULT_WIDTH = 72
  
  # Format an +Array+ of +Strings+ as a table and return an +Array+ of lines
  # in the result.
  def self.table(items)
    if items.empty?
      []
    else
      columns = get_columns
      item_width = items.map { |item| item.length }.max + 2
      items_per_line = [1, columns / item_width].max
      num_lines = (items.length.to_f / items_per_line).ceil
      format_table(items, item_width, items_per_line, num_lines)
    end
  end

  # Wrap a +String+ to fit the terminal and return an +Array+ of lines in the
  # result.
  def self.wrap(text)
    columns = get_columns
    position = 0
    lines = []
    while position < text.length
      lines << get_wrap_segment(text[position, text.length], columns)
      position += lines.last.length + 1
    end
    lines
  end

  private

  # Return the width of the terminal in columns.
  def self.get_columns
    require 'readline'
    begin
      columns = Readline.get_screen_size[1]
      columns > 0 ? columns : DEFAULT_WIDTH
    rescue NotImplementedError
      DEFAULT_WIDTH
    end
  end

  # Return an +Array+ of lines of the given items formatted as a table.
  def self.format_table(items, item_width, items_per_line, num_lines)
    num_lines.times.map do |i|
      items[i * items_per_line, items_per_line].map do |item|
        item.ljust(item_width)
      end.join
    end
  end

  # Return a wrapped line of output from the start of the given text.
  def self.get_wrap_segment(text, columns)
    segment, sep, text = text.partition(' ')
    while !text.empty? && segment.length < columns
      head, sep, text = text.partition(' ')
      segment << " #{head}"
    end
    if segment.length > columns && segment.include?(' ')
      segment.rpartition(' ')[0]
    else
      segment
    end
  end

end
