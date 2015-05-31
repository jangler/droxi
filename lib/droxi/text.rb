# Module containing text-manipulation methods.
module Text
  # The assumed width of the terminal if GNU Readline can't retrieve it.
  DEFAULT_WIDTH = 72

  # Format an +Array+ of +Strings+ as a table and return an +Array+ of lines
  # in the result.
  def self.table(items)
    return [] if items.empty?
    width = terminal_width
    item_width = items.map(&:size).max + 2
    items_per_line = [1, width / item_width].max
    format_table(items, item_width, items_per_line)
  end

  # Wrap a +String+ to fit the terminal and return an +Array+ of lines in the
  # result.
  def self.wrap(text)
    width = terminal_width
    position = 0
    lines = []
    while position < text.size
      lines << get_wrap_segment(text[position, text.size], width)
      position += lines.last.size + 1
    end
    lines
  end

  # Split a +String+ into tokens, allowing for backslash-escaped spaces, and
  # return the resulting +Array+.
  def self.tokenize(string, include_empty: false)
    tokens = string.split
    tokens << '' if include_empty && (string.empty? || string.end_with?(' '))
    tokens.reduce([]) do |list, token|
      list << if !list.empty? && list.last.end_with?('\\')
                "#{list.pop.chop} #{token}"
              else
                token
              end
    end
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
    lines = []
    items = items.dup
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
      break if text.empty? || line.size >= width
    end
    line.strip!
    trim_last_word = line.size > width && line.include?(' ')
    trim_last_word ? line.rpartition(' ').first : line
  end
end
