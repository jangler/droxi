require_relative 'settings'

# Encapsulates the session state of the client.
class State

  # +Hash+ of remote file paths to cached file metadata.
  attr_reader :cache

  # The remote working directory path.
  attr_reader :pwd

  # The previous remote working directory path.
  attr_reader :oldpwd

  # The previous local working directory path.
  attr_accessor :local_oldpwd
  
  # +true+ if the client has requested to quit, +false+ otherwise.
  attr_accessor :exit_requested

  # Return a new application state that uses the given client. Starts at the
  # Dropbox root and with an empty cache.
  def initialize(client)
    @cache = {}
    @client = client
    @exit_requested = false
    @pwd = '/'
    @oldpwd = Settings[:oldpwd] || '/'
    @local_oldpwd = Dir.pwd
  end

  # Return a +Hash+ of the Dropbox metadata for a file, or +nil+ if the file
  # does not exist.
  def metadata(path)
    tokens = path.split('/').drop(1)

    for i in 0..tokens.length
      partial_path = '/' + tokens.take(i).join('/')
      unless have_all_info_for(partial_path)
        begin
          data = @cache[partial_path] = @client.metadata(partial_path)
        rescue DropboxError
          return nil
        end
        if data.include?('contents')
          data['contents'].each do |datum|  
            @cache[datum['path']] = datum
          end
        end
      end
    end

    @cache[path]
  end

  # Return an +Array+ of paths of files in a Dropbox directory.
  def contents(path)
    metadata(path)
    path = "#{path}/".sub('//', '/')
    @cache.keys.select do |key|
      key.start_with?(path) && key != path && !key.sub(path, '').include?('/')
    end
  end

  # Return +true+ if the Dropbox path is a directory, +false+ otherwise.
  def directory?(path)
    metadata(File.dirname(path))
    @cache.include?(path) && @cache[path]['is_dir']
  end

  # Set the remote working directory, and set the previous remote working
  # directory to the old value.
  def pwd=(value)
    @oldpwd, @pwd = @pwd, value
    Settings[:oldpwd] = @oldpwd
  end

  # Expand a Dropbox file path and return the result.
  def resolve_path(path)
    path = "#{@pwd}/#{path}" unless path.start_with?('/')
    path.gsub!('//', '/')
    while path.sub!(/\/([^\/]+?)\/\.\./, '')
    end
    path.chomp!('/')
    path = '/' if path.empty?
    path
  end

  # Expand an +Array+ of file globs into an an +Array+ of Dropbox file paths
  # and return the result.
  def expand_patterns(patterns)
    patterns.map do |pattern|
      final_pattern = resolve_path(pattern)

      matches = []
      @client.metadata(File.dirname(final_pattern))['contents'].each do |data|
        path = data['path']
        matches << path if File.fnmatch(final_pattern, path)
      end

      if matches.empty?
        [final_pattern]
      else
        matches
      end
    end.flatten
  end

  # Return an +Array+ of potential tab-completions for a partial Dropbox file
  # path.
  def complete_file(word)
    tab_complete(word, false)
  end

  # Return an +Array+ of potential tab-completions for a partial Dropbox
  # directory path.
  def complete_dir(word)
    tab_complete(word, true)
  end

  private

  def have_all_info_for(path)
    @cache.include?(path) &&
    (@cache[path].include?('contents') || !@cache[path]['is_dir'])
  end

  def complete(path, prefix_length, dir_only)
    @cache.keys.select do |key|
      key.start_with?(path) && key != path &&
      !(dir_only && !@cache[key]['is_dir'])
    end.map do |key|
      if @cache[key]['is_dir']
        key += '/' 
      else
        key += ' '
      end
      key[prefix_length, key.length]
    end
  end

  def tab_complete(word, dir_only)
    begin
      path = resolve_path(word)
      prefix_length = path.length - word.length

      if word.end_with?('/')
        # Treat word as directory
        metadata(path)
        prefix_length += 1
      else
        # Treat word as file
        metadata(File.dirname(path))
      end

      complete(path, prefix_length, dir_only)
    rescue DropboxError
      []
    end
  end

end
