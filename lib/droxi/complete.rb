# Module containing tab-completion logic and methods.
module Complete

  # Return the directory in which to search for potential local tab-completions
  # for a +String+. Defaults to working directory in case of bogus input.
  def self.local_search_path(string)
    begin
      File.expand_path(strip_filename(string))
    rescue
      Dir.pwd
    end
  end

  # Return an +Array+ of potential local tab-completions for a +String+.
  def self.local(string)
    dir = local_search_path(string)
    name = string.end_with?('/') ? '' : File.basename(string)

    Dir.entries(dir).select do |entry|
      entry.start_with?(name) && !/^\.{1,2}$/.match(entry)
    end.map do |entry|
      entry << (File.directory?(dir + '/' + entry) ? '/' : ' ')
      string + entry[name.length, entry.length]
    end
  end

  # Return an +Array+ of potential local tab-completions for a +String+,
  # including only directories.
  def self.local_dir(string)
    local(string).select { |result| result.end_with?('/') }
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
    name = string.end_with?('/') ? '' : File.basename(string)

    state.contents(dir).map do |entry|
      File.basename(entry) 
    end.select do |entry|
      entry.start_with?(name) && !/^\.{1,2}$/.match(entry)
    end.map do |entry|
      entry << (state.directory?(dir + '/' + entry) ? '/' : ' ')
      string + entry[name.length, entry.length]
    end
  end

  # Return an +Array+ of potential remote tab-completions for a +String+,
  # including only directories.
  def self.remote_dir(string, state)
    remote(string, state).select { |result| result.end_with?('/') }
  end

  private

  # Return the name of the directory indicated by a path.
  def self.strip_filename(path)
    if path != '/'
      path.end_with?('/') ? path.sub(/\/$/, '') : File.dirname(path)
    else
      path
    end
  end

  # Return a version of a path with .. and . resolved to appropriate
  # directories.
  def self.collapse(path)
    new_path = path.dup
    nil while new_path.sub!(/[^\/]+\/\.\.\//, '/')
    nil while new_path.sub!('./', '')
    new_path
  end

end
