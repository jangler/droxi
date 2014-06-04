require 'dropbox_sdk'
require 'minitest/autorun'

require_relative '../lib/droxi/commands'
require_relative '../lib/droxi/complete'
require_relative '../lib/droxi/settings'
require_relative '../lib/droxi/state'

describe Complete do
  CHARACTERS = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a

  def random_string(length)
    rand(length).times.map { CHARACTERS.sample }.join
  end

  describe 'when resolving a local search path' do
    it 'must resolve unqualified string to working directory' do
      Complete.local_search_path('').must_equal Dir.pwd
      Complete.local_search_path('f').must_equal Dir.pwd
    end

    it 'must resolve / to root directory' do
      Complete.local_search_path('/').must_equal '/'
      Complete.local_search_path('/f').must_equal '/'
    end

    it 'must resolve directory name to named directory' do
      Complete.local_search_path('/home/').must_equal '/home'
      Complete.local_search_path('/home/f').must_equal '/home'
    end

    it 'must resolve ~/ to home directory' do
      Complete.local_search_path('~/').must_equal Dir.home
      Complete.local_search_path('~/f').must_equal Dir.home
    end

    it 'must resolve ./ to working directory' do
      Complete.local_search_path('./').must_equal Dir.pwd
      Complete.local_search_path('./f').must_equal Dir.pwd
    end

    it 'must resolve ../ to parent directory' do
      Complete.local_search_path('../').must_equal File.dirname(Dir.pwd)
      Complete.local_search_path('../f').must_equal File.dirname(Dir.pwd)
    end

    it 'must resolve a bogus string to working directory' do
      Complete.local_search_path('~bogus/bogus').must_equal Dir.pwd
    end
  end

  describe 'when finding potential local tab completions' do
    def check(path)
      100.times.all? do
        prefix = path + random_string(5)
        Complete.local(prefix).all? { |match| match.start_with?(prefix) }
      end.must_equal true
      1000.times.any? do
        prefix = path + random_string(5)
        !Complete.local(prefix).empty?
      end.must_equal true
    end

    it 'seed must prefix results for unqualified string' do
      check('')
    end

    it 'seed must prefix results for /' do
      check('/')
    end

    it 'seed must prefix results for named directory' do
      check('/home/')
    end

    it 'seed must prefix results for ~/' do
      check('~/')
    end

    it 'seed must prefix results for ./' do
      check('./')
    end

    it 'seed must prefix results for ../' do
      check('../')
    end

    it "won't raise an exception on a bogus string" do
      Complete.local('~bogus')
    end
  end

  describe 'when finding local directory tab completions' do
    it 'must include all directories and only directories' do
      entries = Dir.entries(Dir.pwd).select do |entry|
        File.directory?(entry) && !/^..?$/.match(entry)
      end
      matches = Complete.local_dir('').map { |match| match.chomp('/') }
      matches.sort.must_equal entries.sort
    end

    it 'must append a / to the end of options' do
      Complete.local_dir('').all? { |option| option.end_with?('/') }
    end
  end

  describe 'when resolving a remote search path' do
    client = DropboxClient.new(Settings[:access_token])
    begin
      client.file_create_folder('/testing')
    rescue DropboxError
      nil
    end
    state = State.new(client)
    state.pwd = '/testing'

    it 'must resolve unqualified string to working directory' do
      Complete.remote_search_path('', state).must_equal state.pwd
      Complete.remote_search_path('f', state).must_equal state.pwd
    end

    it 'must resolve / to root directory' do
      Complete.remote_search_path('/', state).must_equal '/'
      Complete.remote_search_path('/f', state).must_equal '/'
    end

    it 'must resolve directory name to named directory' do
      Complete.remote_search_path('/testing/', state).must_equal '/testing'
      Complete.remote_search_path('/testing/f', state).must_equal '/testing'
    end

    it 'must resolve ./ to working directory' do
      Complete.remote_search_path('./', state).must_equal state.pwd
      Complete.remote_search_path('./f', state).must_equal state.pwd
    end

    it 'must resolve ../ to parent directory' do
      parent = File.dirname(state.pwd)
      Complete.remote_search_path('../', state).must_equal parent
      Complete.remote_search_path('../f', state).must_equal parent
    end
  end

  describe 'when finding remote tab completions' do
    client = DropboxClient.new(Settings[:access_token])
    state = State.new(client)
    state.pwd = '/testing'
    Commands::RM.exec(client, state, '/testing/*')
    %w(/testing /testing/one /testing/two).each do |dir|
      Commands::MKDIR.exec(client, state, dir) unless state.metadata(dir)
    end
    `echo hello > test.txt`
    Commands::PUT.exec(client, state, 'test.txt')
    `rm test.txt`

    it 'must return only matches of which the string is a prefix' do
      Complete.remote('t', state).must_equal ['two/', 'test.txt ']
    end

    it 'must return only directories if requested' do
      Complete.remote_dir('', state).must_equal %w(one/ two/)
    end
  end

  describe 'when resolving command names' do
    before do
      @words = %w(plank plague plonk lake lag lock)
    end

    it 'must return matches if and only if the string is a prefix' do
      Complete.command('pla', @words).length.must_equal 2
    end

    it 'must return matches that end with a space' do
      Complete.command('plank', @words).must_equal ['plank ']
    end
  end
end
