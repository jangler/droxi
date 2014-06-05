# Module containing text-manipulation methods.
module Text
  # The assumed width of the terminal if GNU Readline can't retrieve it.
  DEFAULT_WIDTH = 72

  # Format an +Array+ of +Strings+ as a table and return an +Array+ of lines
  # in the result.
  def self.table(items)
    return [] if items.empty?
    width = terminal_width
    item_width = items.map { |item| item.length }.max + 2
    items_per_line = [1, width / item_width].max
    format_table(items, item_width, items_per_line)
  end

  # Wrap a +String+ to fit the terminal and return an +Array+ of lines in the
  # result.
  def self.wrap(text)
    width, position = terminal_width, 0
    lines = []
    while position < text.length
      lines << get_wrap_segment(text[position, text.length], width)
      position += lines.last.length + 1
    end
    lines
  end

  private

  # Return the width of the terminal in columns.
  def self.terminal_width
    require 'readline'
    width = Readline.get_screen_size[1]
    width > 0 ? width : DEFAULT_WIDTH
  rescue NotImplementedError
    DEFAULT_WIDTH
  end

  # Return an +Array+ of lines of the given items formatted as a table.
  def self.format_table(items, item_width, columns)
    lines, items = [], items.dup
    until items.empty?
      lines << items.shift(columns).map { |item| item.ljust(item_width) }.join
    end
    lines
  end

  # Return a wrapped line of output from the start of the given text.
  def self.get_wrap_segment(text, width)
    line = ''
    loop do
      head, _, text = text.partition(' ')
      line << "#{head} "
      break if text.empty? || line.length >= width
    end
    line.strip!
    trim_last_word = line.length > width && line.include?(' ')
    trim_last_word ? line.rpartition(' ')[0] : line
  end
end
