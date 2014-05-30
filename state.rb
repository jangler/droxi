class State
  attr_reader :oldpwd, :pwd

  def initialize
    @oldpwd = @pwd = '/'
  end

  def pwd=(value)
    @oldpwd, @pwd = @pwd, value
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
end
