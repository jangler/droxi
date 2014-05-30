require 'minitest/autorun'

require_relative '../state'
require_relative '../settings'

describe State do
  describe 'when initializing' do
    it 'must set pwd to root' do
      state = State.new
      state.pwd.must_equal '/'
    end

    it 'must set oldpwd to saved oldpwd' do
      state = State.new
      if Settings.include?(:oldpwd)
        state.oldpwd.must_equal Settings[:oldpwd]
      end
    end
  end

  describe 'when setting pwd' do
    it 'must change pwd' do
      state = State.new
      state.pwd = '/testing'
      state.pwd.must_equal '/testing'
    end

    it 'must set oldpwd to previous pwd' do
      state = State.new
      state.pwd = '/testing'
      state.pwd = '/'
      state.oldpwd.must_equal '/testing'
    end
  end

  describe 'when resolving path' do
    it 'must resolve root to itself' do
      State.new.resolve_path('/').must_equal '/'
    end

    it 'must resolve qualified path to itself' do
      state = State.new
      state.pwd = '/alpha'
      state.resolve_path('/beta').must_equal '/beta'
    end

    it 'must resolve unqualified path to relative path' do
      state = State.new
      state.pwd = '/alpha'
      state.resolve_path('beta').must_equal '/alpha/beta'
    end

    it 'must resolve .. to upper directory' do
      state = State.new
      state.pwd = '/alpha/beta/gamma'
      state.resolve_path('../..').must_equal '/alpha'
    end
  end
end
