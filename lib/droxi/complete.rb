require_relative 'commands'
require_relative 'text'

# Module containing tab-completion logic and methods.
module Complete
  # Return an +Array+ of completion options for the given input line and
  # client state.
  def self.complete(line, state)
    tokens = Text.tokenize(line, include_empty: true)
    type = completion_type(tokens)
    completion_options(type, tokens.last, state).map do |option|
      option.gsub(' ', '\ ').sub(/\\ $/, ' ')
        .split.drop(tokens.last.count(' ')).join(' ')
        .sub(/[^\\\/]$/, '\0 ')
    end
  end

  private

  # Return an +Array+ of potential tab-completion options for a given
  # completion type, word, and client state.
  def self.completion_options(type, word, state)
    case type
    when 'COMMAND'     then command(word, Commands::NAMES)
    when 'LOCAL_FILE'  then local(word)
    when 'LOCAL_DIR'   then local_dir(word)
    when 'REMOTE_FILE' then remote(word, state)
    when 'REMOTE_DIR'  then remote_dir(word, state)
    else []
    end
  end

  # Return a +String+ representing the type of tab-completion that should be
  # performed, given the current line buffer state.
  def self.completion_type(tokens)
    index = tokens.drop_while { |token| token[/^-\w+$/] }.size
    if index <= 1
      'COMMAND'
    elsif Commands::NAMES.include?(tokens.first)
      cmd = Commands.const_get(tokens.first.upcase.to_sym)
      cmd.type_of_arg(index - 2)
    end
  end

  # Return an +Array+ of potential command name tab-completions for a +String+.
  def self.command(string, names)
    names.select { |n| n.start_with?(string) }.map { |n| n + ' ' }
  end

  # Return the directory in which to search for potential local tab-completions
  # for a +String+.
  def self.local_search_path(string)
    File.expand_path(strip_filename(string))
  rescue ArgumentError
    string
  end

  # Return an +Array+ of potential local tab-completions for a +String+.
  def self.local(string)
    dir = local_search_path(string)
    basename = basename(string)

    begin
      matches = Dir.entries(dir).select { |entry| match?(basename, entry) }
      matches.map do |entry|
        final_match(string, entry, File.directory?(dir + '/' + entry))
      end
    rescue Errno::ENOENT
      []
    end
  end

  # Return an +Array+ of potential local tab-completions for a +String+,
  # including only directories.
  def self.local_dir(string)
    local(string).select { |match| match.end_with?('/') }
  end

  # Return the directory in which to search for potential remote
  # tab-completions for a +String+.
  def self.remote_search_path(string, state)
    path = case
           when string.empty? then state.pwd + '/'
           when string.start_with?('/') then string
           else state.pwd + '/' + string
           end

    strip_filename(collapse(path))
  end

  # Return an +Array+ of potential remote tab-completions for a +String+.
  def self.remote(string, state)
    dir = remote_search_path(string, state)
    basename = basename(string)

    entries = state.contents(dir).map { |entry| File.basename(entry) }
    matches = entries.select { |entry| match?(basename, entry) }
    matches.map do |entry|
      final_match(string, entry, state.directory?(dir + '/' + entry))
    end
  end

  # Return an +Array+ of potential remote tab-completions for a +String+,
  # including only directories.
  def self.remote_dir(string, state)
    remote(string, state).select { |result| result.end_with?('/') }
  end

  def self.basename(string)
    string.end_with?('/') ? '' : File.basename(string)
  end

  def self.match?(prefix, candidate)
    candidate.start_with?(prefix) && !candidate[/^\.\.?$/]
  end

  def self.final_match(string, candidate, is_dir)
    string + candidate.partition(basename(string))[2] + (is_dir ? '/' : ' ')
  end

  # Return the name of the directory indicated by a path.
  def self.strip_filename(path)
    return path if path == '/'
    path.end_with?('/') ? path.sub(/\/$/, '') : File.dirname(path)
  end

  # Return a version of a path with .. and . resolved to appropriate
  # directories.
  def self.collapse(path)
    new_path = path.dup
    nil while new_path.sub!(%r{[^/]+/\.\./}, '/')
    nil while new_path.sub!('./', '')
    new_path
  end
end
