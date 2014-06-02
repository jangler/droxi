require 'minitest/autorun'

require_relative '../lib/droxi/state'
require_relative '../lib/droxi/settings'

describe State do
  describe 'when initializing' do
    it 'must set pwd to root' do
      State.new(nil).pwd.must_equal '/'
    end

    it 'must set oldpwd to saved oldpwd' do
      if Settings.include?(:oldpwd)
        State.new(nil).oldpwd.must_equal Settings[:oldpwd]
      end
    end
  end

  describe 'when setting pwd' do
    it 'must change pwd and set oldpwd to previous pwd' do
      state = State.new(nil)
      state.pwd = '/testing'
      state.pwd.must_equal '/testing'
      state.pwd = '/'
      state.oldpwd.must_equal '/testing'
    end
  end

  describe 'when resolving path' do
    state = State.new(nil)

    it 'must resolve root to itself' do
      state.resolve_path('/').must_equal '/'
    end

    it 'must resolve qualified path to itself' do
      state.pwd = '/alpha'
      state.resolve_path('/beta').must_equal '/beta'
    end

    it 'must resolve unqualified path to relative path' do
      state.pwd = '/alpha'
      state.resolve_path('beta').must_equal '/alpha/beta'
    end

    it 'must resolve .. to upper directory' do
      state.pwd = '/alpha/beta/gamma'
      state.resolve_path('../..').must_equal '/alpha'
    end
  end
end
