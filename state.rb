require_relative 'settings'

class State
  attr_reader :oldpwd, :pwd, :cache

  def initialize
    @pwd = '/'
    @oldpwd = Settings[:oldpwd] || '/'
    @cache = {}
  end

  def metadata(client, path)
    tokens = path.split('/').drop(1)

    for i in 0..tokens.length
      partial_path = '/' + tokens.take(i).join('/')
      unless @cache.include?(partial_path) &&
             (@cache[partial_path].include?('contents') ||
              !@cache[partial_path]['is_dir'])
        data = @cache[partial_path] = begin
          client.metadata(partial_path)
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

  def contents(client, path)
    metadata(client, path)
    path = "#{path}/".sub('//', '/')
    @cache.keys.select do |key|
      key.start_with?(path) && key != path && !key.sub(path, '').include?('/')
    end
  end

  def tab_complete(client, word)
    path = resolve_path(word)
    prefix_length = path.length - word.length
    if word.end_with?('/')
      metadata(client, path)
      prefix_length += 1
    else
      metadata(client, File.dirname(path))
    end
    @cache.keys.select do |key|
      key.start_with?(path) && key != path
    end.map do |key|
      key += '/' if @cache[key]['is_dir']
      key[prefix_length, key.length]
    end
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
end
