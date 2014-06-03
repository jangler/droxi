require_relative 'settings'

# Represents a failure of a glob expression to match files.
class GlobError < ArgumentError
end

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
  def metadata(path, require_contents=true)
    tokens = path.split('/').drop(1)

    for i in 0..tokens.length
      partial_path = '/' + tokens.take(i).join('/')
      unless have_all_info_for(partial_path, require_contents)
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
    path = resolve_path(path)
    metadata(path)
    path = "#{path}/".sub('//', '/')
    @cache.keys.select do |key|
      key.start_with?(path) && key != path && !key.sub(path, '').include?('/')
    end
  end

  # Return +true+ if the Dropbox path is a directory, +false+ otherwise.
  def directory?(path)
    path = resolve_path(path)
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
  def resolve_path(arg)
    path = arg.start_with?('/') ? arg.dup : "#{@pwd}/#{arg}"
    path.gsub!('//', '/')
    nil while path.sub!(/\/([^\/]+?)\/\.\./, '')
    nil while path.sub!('./', '')
    path.sub!(/\/\.$/, '')
    path.chomp!('/')
    path = '/' if path.empty?
    path
  end

  # Expand an +Array+ of file globs into an an +Array+ of Dropbox file paths
  # and return the result.
  def expand_patterns(patterns, preserve_root=false)
    patterns.map do |pattern|
      final_pattern = if pattern.length > 1 and !pattern.end_with?('./')
        pattern.chomp('/')
      else
        pattern
      end
      final_pattern = resolve_path(final_pattern)

      if pattern.end_with?('/') || pattern.end_with?('.')
        metadata(final_pattern) ? pattern : GlobError.new(pattern)
      else
        matches = []
        metadata(File.dirname(final_pattern))['contents'].each do |data|
          path = data['path']
          matches << path if File.fnmatch(final_pattern, path)
        end
        matches << '/' if final_pattern == '/'

        if preserve_root
          matches.map! do |match|
            if pattern.include?('/')
              pattern.rpartition('/')[0, 2].join + match.rpartition('/')[2]
            else
              pattern + '/' + match.rpartition('/')[2]
            end
          end
        end

        matches.empty? ? GlobError.new(pattern) : matches
      end
    end.flatten
  end

  # Recursively remove directory contents from metadata cache. Yield lines of
  # (error) output if a block is given.
  def forget_contents(partial_path)
    path = resolve_path(partial_path)
    if @cache.include?(path) && @cache[path].include?('contents')
      @cache[path].delete('contents')
      @cache.keys.each do |key|
        @cache.delete(key) if key.start_with?(path) && key != path
      end
    elsif block_given?
      yield "forget: #{partial_path}: Nothing to forget"
    end
  end

  private

  def have_all_info_for(path, require_contents=true)
    @cache.include?(path) && (
      !require_contents ||
      !@cache[path]['is_dir'] ||
      @cache[path].include?('contents')
    )
  end

end
