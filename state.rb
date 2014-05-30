class State
  attr_reader :oldpwd, :pwd

  def initialize
    @oldpwd = @pwd = '/'
  end

  def pwd=(value)
    @oldpwd, @pwd = @pwd, value
  end
end
