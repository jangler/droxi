require 'dropbox_sdk'
require 'minitest/autorun'

require_relative '../lib/droxi/commands'
require_relative '../lib/droxi/settings'
require_relative '../lib/droxi/state'

describe State do
  client = DropboxClient.new(Settings[:access_token])

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

    it 'must resolve . to current directory' do
      state.pwd = '/alpha'
      state.resolve_path('.').must_equal '/alpha'
    end

    it 'must resolve .. to upper directory' do
      state.pwd = '/alpha/beta/gamma'
      state.resolve_path('../..').must_equal '/alpha'
    end
  end

  describe 'when forgetting directory contents' do
    before do
      @state = State.new(nil)
      ['/', '/dir'].each { |dir| @state.cache[dir] = { 'contents' => nil } }
      2.times { |i| @state.cache["/dir/file#{i}"] = {} }
    end

    it 'must yield an error for a bogus path' do
      lines = []
      @state.forget_contents('bogus') { |line| lines << line }
      lines.length.must_equal 1
    end

    it 'must yield an error for a non-directory path' do
      lines = []
      @state.forget_contents('/dir/file0') { |line| lines << line }
      lines.length.must_equal 1
    end

    it 'must yield an error for an already forgotten path' do
      lines = []
      @state.forget_contents('dir')
      @state.forget_contents('dir') { |line| lines << line }
      lines.length.must_equal 1
    end

    it 'must forget contents of given directory' do
      @state.forget_contents('dir')
      @state.cache['/dir'].include?('contents').must_equal false
      @state.cache.keys.any? do |key|
        key.start_with?('/dir/')
      end.must_equal false
    end

    it 'must forget contents of subdirectories' do
      @state.forget_contents('/')
      @state.cache['/'].include?('contents').must_equal false
      @state.cache.keys.any? do |key|
        key.length > 1
      end.must_equal false
    end
  end

  describe 'when querying metadata' do
    before do
      @state = State.new(client)
    end

    it 'must return metadata for a valid path' do
      @state.metadata('/testing').must_be_instance_of Hash
    end

    it 'must return nil for an invalid path' do
      @state.metadata('/bogus').must_be_nil
    end
  end

  describe 'when expanding patterns' do
    before do
      @state = State.new(client)
      %w(/testing /testing/sub1 /testing/sub2).each do |path|
        next if @state.metadata(path)
        Commands::MKDIR.exec(client, @state, path)
      end
      @state.pwd = '/testing'
    end

    it 'must not preserve relative paths by default' do
      @state.expand_patterns(['*1']).must_equal ['/testing/sub1']
    end

    it 'must preserve relative paths if requested' do
      @state.expand_patterns(['*2'], true).must_equal ['sub2']
    end

    it 'must return GlobErrors for non-matches' do
      @state.expand_patterns(['*3']).must_equal [GlobError.new('*3')]
    end
  end
end
