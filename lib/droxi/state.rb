require_relative 'cache'
require_relative 'settings'

# Represents a failure of a glob expression to match files.
GlobError = Class.new(ArgumentError)

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

  # +true+ if the --debug option was given, +false+ otherwise.
  attr_accessor :debug_enabled

  # Return a new application state that uses the given client. Starts at the
  # Dropbox root and with an empty cache.
  def initialize(client)
    @cache = Cache.new
    @client = client
    @exit_requested = false
    @debug_enabled = false
    @pwd = '/'
    @oldpwd = Settings[:oldpwd] || '/'
    @local_oldpwd = Dir.pwd
  end

  # Return a +Hash+ of the Dropbox metadata for a file, or +nil+ if the file
  # does not exist.
  def metadata(path, require_contents = true)
    path = path.downcase
    tokens = path.split('/').drop(1)

    (0..tokens.size).each do |i|
      partial_path = '/' + tokens.take(i).join('/')
      next if @cache.full_info?(partial_path, require_contents)
      return nil unless fetch_metadata(partial_path)
    end

    @cache[path]
  end

  # Return an +Array+ of paths of files in a Dropbox directory.
  def contents(path)
    path = path.downcase
    path = resolve_path(path)
    metadata(path)
    path = "#{path}/".sub('//', '/')
    @cache.keys.select do |key|
      key.start_with?(path) && key != path && !key.sub(path, '').include?('/')
    end.map { |key| @cache[key]['path'] }
  end

  # Return +true+ if the Dropbox path is a directory, +false+ otherwise.
  def directory?(path)
    path = path.downcase
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
    # REVIEW: See if we can do this in fewer lines (e.g. without two gsub!s).
    path = arg.start_with?('/') ? arg.dup : "#{@pwd}/#{arg}"
    path.gsub!('//', '/')
    nil while path.sub!(%r{/([^/]+?)/\.\.}, '')
    nil while path.sub!('./', '')
    path.sub!(/\/\.$/, '')
    path.chomp!('/')
    path.gsub!('//', '/')
    path.empty? ? '/' : path
  end

  # Expand an +Array+ of file globs into an an +Array+ of Dropbox file paths
  # and return the result.
  def expand_patterns(patterns, preserve_root = false)
    patterns.flat_map do |pattern|
      path = resolve_path(pattern)
      if directory?(path)
        preserve_root ? pattern : path
      else
        get_matches(pattern, path, preserve_root)
      end
    end
  end

  # Recursively remove directory contents from metadata cache. Yield lines of
  # (error) output if a block is given.
  def forget_contents(partial_path)
    path = resolve_path(partial_path).downcase
    if @cache.fetch(path, {}).include?('contents')
      @cache[path]['contents'].dup.each { |m| @cache.remove(m['path']) }
      @cache[path].delete('contents')
    elsif block_given?
      yield "forget: #{partial_path}: nothing to forget"
    end
  end

  private

  # Cache metadata for the remote file for a given path. Return +true+ if
  # successful, +false+ otherwise.
  def fetch_metadata(path)
    data = @client.metadata(path.downcase)
    return true if data['is_deleted']
    @cache.add(data)
    true
  rescue DropboxError
    false
  end

  # Return an +Array+ of file paths matching a glob pattern, or a GlobError if
  # no files were matched.
  def get_matches(pattern, path, preserve_root)
    path = path.downcase
    dir = File.dirname(path)
    matches = contents(dir).select do |entry|
                File.fnmatch(path, entry.downcase)
              end
    return GlobError.new(pattern) if matches.empty?
    return matches unless preserve_root
    prefix = pattern.rpartition('/')[0, 2].join
    matches.map { |match| prefix + match.rpartition('/')[2] }
  end
end
