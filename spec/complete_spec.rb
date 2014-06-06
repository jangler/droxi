require 'minitest/autorun'

require_relative 'testutils'
require_relative '../lib/droxi/commands'
require_relative '../lib/droxi/complete'

describe Complete do
  CHARACTERS = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a

  _, state = TestUtils.create_client_and_state

  def random_string(length)
    rand(length).times.map { CHARACTERS.sample }.join
  end

  def remote_contents(state, path)
    state.contents(path).map do |entry|
      entry += (state.directory?(entry) ? '/' : ' ')
      entry[1, entry.size].gsub(' ', '\\ ').sub(/\\ $/, ' ')
    end
  end

  def local_contents
    files = Dir.entries(Dir.pwd).map do |entry|
      entry << (File.directory?(entry) ? '/' : ' ')
    end
    files.reject { |file| file[/^\.\.?\/$/] }
  end

  describe 'when given an empty string or whitespace' do
    it 'lists all command names' do
      names = Commands::NAMES.map { |n| "#{n} " }
      Complete.complete('', state).must_equal names
      Complete.complete('  ', state).must_equal names
    end
  end

  describe 'when given a letter' do
    it 'lists all command names starting with that letter' do
      letter = 'c'
      names = Commands::NAMES.map { |n| "#{n} " }
      matches = names.select { |n| n.start_with?(letter) }
      Complete.complete(letter, state).sort.must_equal matches.sort
    end
  end

  describe 'when given a context for local files' do
    it 'lists all local files except . and .. and end with correct char' do
      Complete.complete('put ', state).sort.must_equal local_contents.sort
    end
  end

  describe 'when given a context for local directories' do
    it 'lists all local dirs except . and .. and end with correct char' do
      dirs = local_contents.reject { |entry| entry.end_with?(' ') }
      Complete.complete('lcd ', state).sort.must_equal dirs.sort
    end
  end

  describe 'when given local context and faulty path' do
    it 'must return empty list' do
      Complete.complete('put bogus/', state).must_equal [] # fictional
      Complete.complete('put ~bogus/', state).must_equal [] # malformed
    end
  end

  describe 'when given an implicit context for remote files' do
    it 'lists all remote files and end with correct char' do
      state.pwd = '/'
      entries = remote_contents(state, '/')
      Complete.complete('put thing ', state).sort.must_equal entries.sort
    end
  end

  describe 'when given an explicit, absolute context for remote files' do
    it 'lists all remote files in path and end with correct char' do
      state.pwd = '/'

      entries = remote_contents(state, '/testing').map { |e| "/#{e}" }
      Complete.complete('ls /testing/', state).sort.must_equal entries.sort

      entries.map! { |e| e.sub('/testing/', '/testing/../testing/./') }
      Complete.complete('ls /testing/../testing/./', state).sort
        .must_equal entries.sort
    end
  end

  describe 'when given an explicit, relative context for remote files' do
    it 'lists all remote files in path and end with correct char' do
      state.pwd = '/'

      entries = remote_contents(state, '/testing')
      Complete.complete('ls testing/', state).sort.must_equal entries.sort

      entries.map! { |e| e.sub('testing/', 'testing/../testing/./') }
      Complete.complete('ls testing/../testing/./', state).sort
        .must_equal entries.sort
    end
  end

  describe 'when given a context for remote directories' do
    it 'lists all remote dirs and end with correct char' do
      state.pwd = '/'
      dirs = remote_contents(state, '/').select { |e| e.end_with?('/') }
      Complete.complete('cd ', state).sort.must_equal dirs.sort
    end
  end

  describe 'when given name with spaces' do
    it 'must continue to match correctly' do
      `touch a\\ b\\ c`
      matches = local_contents.select { |entry| entry.start_with?('a\\ ') }
      Complete.complete('lcd a\\ ', state).sort.must_equal matches.sort
      `rm a\\ b\\ c`
    end
  end

  describe 'when given an unworkable context' do
    it 'lists nothing' do
      Complete.complete('debug ', state).must_equal []
    end
  end
end
