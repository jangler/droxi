require_relative 'settings'

class State
  attr_reader :oldpwd, :pwd

  def initialize
    @pwd = '/'
    @oldpwd = if Settings.include?(:oldpwd)
      Settings[:oldpwd]
    else
      '/'
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
