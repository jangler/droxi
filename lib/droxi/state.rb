require_relative 'settings'

class State
  attr_reader :oldpwd, :pwd, :cache
  attr_accessor :local_oldpwd

  def initialize
    @pwd = '/'
    @oldpwd = Settings[:oldpwd] || '/'
    @local_oldpwd = Dir.pwd
    @cache = {}
  end

  def have_all_info_for(path)
    @cache.include?(path) &&
    (@cache[path].include?('contents') || !@cache[path]['is_dir'])
  end

  def metadata(client, path)
    tokens = path.split('/').drop(1)

    for i in 0..tokens.length
      partial_path = '/' + tokens.take(i).join('/')
      unless have_all_info_for(partial_path)
        begin
          data = @cache[partial_path] = client.metadata(partial_path)
        rescue DropboxError
          return
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

  def contents(client, path)
    metadata(client, path)
    path = "#{path}/".sub('//', '/')
    @cache.keys.select do |key|
      key.start_with?(path) && key != path && !key.sub(path, '').include?('/')
    end
  end

  def is_dir?(client, path)
    metadata(client, File.dirname(path))
    @cache.include?(path) && @cache[path]['is_dir']
  end

  def pwd=(value)
    @oldpwd, @pwd = @pwd, value
    Settings[:oldpwd] = @oldpwd
  end

  def resolve_path(path)
    path = "#{@pwd}/#{path}" unless path.start_with?('/')
    path.gsub!('//', '/')
    while path.sub!(/\/([^\/]+?)\/\.\./, '')
    end
    path.chomp!('/')
    path = '/' if path.empty?
    path
  end

  def expand_patterns(client, patterns)
    patterns.map do |pattern|
      final_pattern = resolve_path(pattern)

      matches = []
      client.metadata(File.dirname(final_pattern))['contents'].each do |data|
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

  def file_complete(client, word)
    tab_complete(client, word, false)
  end

  def dir_complete(client, word)
    tab_complete(client, word, true)
  end

  private

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

  def tab_complete(client, word, dir_only)
    path = resolve_path(word)
    prefix_length = path.length - word.length

    if word.end_with?('/')
      # Treat word as directory
      metadata(client, path)
      prefix_length += 1
    else
      # Treat word as file
      metadata(client, File.dirname(path))
    end

    complete(path, prefix_length, dir_only)
  end
end
