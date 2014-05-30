require 'dropbox_sdk'
require 'minitest/autorun'

require_relative '../commands'
require_relative '../settings'

client = DropboxClient.new(Settings[:access_token])
state = Struct.new(:working_dir).new('/')

begin
  client.file_create_folder('/testing')
rescue DropboxError
end

describe Commands do
  describe 'when executing a shell command' do
    it 'must yield the output' do
      lines = []
      Commands.shell('echo testing') { |line| lines << line }
      lines.must_equal(['testing'])
    end
  end

  describe 'when executing the cd command' do
    it 'must change to the root directory when given 0 args' do
      state.working_dir = '/testing'
      Commands.cd(client, state, [])
      state.working_dir.must_equal '/'
    end

    it 'must change to the stated directory when given 1 arg' do
      state.working_dir = '/'
      Commands.cd(client, state, ['/testing'])
      state.working_dir.must_equal '/testing'
    end

    it 'must raise a UsageError when given 2 or more args' do
      proc { Commands.cd(client, state, ['1', '2']) }.must_raise UsageError
    end
  end

  describe 'when executing the get command' do
    it 'must raise a UsageError when given 0 args' do
      proc { Commands.get(client, state, []) }.must_raise UsageError
    end

    it 'must get a file of the same name when given 1 arg' do
      `echo hello > test.txt`
      open('test.txt', 'rb') do |file|
        client.put_file('/testing/test.txt', file)
      end
      `rm test.txt`
      Commands.get(client, state, ['/testing/test.txt'])
      client.file_delete('/testing/test.txt')
      `ls test.txt`.chomp.must_equal 'test.txt'
      `rm test.txt`
    end

    it 'must get a file as the stated name when given 2 args' do
      `echo hello > test.txt`
      open('test.txt', 'rb') do |file|
        client.put_file('/testing/test.txt', file)
      end
      `rm test.txt`
      Commands.get(client, state, ['/testing/test.txt', 'dest.txt'])
      client.file_delete('/testing/test.txt')
      `ls dest.txt`.chomp.must_equal 'dest.txt'
      `rm dest.txt`
    end

    it 'must raise a UsageError when given 3 or more args' do
      proc { Commands.get(client, state, [1, 2, 3]) }.must_raise UsageError
    end
  end

  describe 'when executing the ls command' do
    it 'must list the working directory contents when given 0 args' do
      client.file_create_folder('/testing/test')
      state.working_dir = '/testing'
      lines = []
      Commands.ls(client, state, []) { |line| lines << line }
      lines.must_equal(['test'])
      client.file_delete('/testing/test')
    end

    it 'must list the stated directory contents when given 1 arg' do
      state.working_dir = '/'
      client.file_create_folder('/testing/test')
      lines = []
      Commands.ls(client, state, ['/testing']) { |line| lines << line }
      lines.must_equal(['test'])
      client.file_delete('/testing/test')
    end

    it 'must raise a UsageError when given 2 or more args' do
      proc { Commands.ls(client, state, ['1', '2']) }.must_raise UsageError
    end
  end

  describe 'when executing the mkdir command' do
    it 'must raise a UsageError when given 0 args' do
      proc { Commands.mkdir(client, state, []) }.must_raise UsageError
    end

    it 'must create a directory when given 1 arg' do
      Commands.mkdir(client, state, ['/testing/test'])
      client.metadata('/testing/test')['is_deleted'].wont_equal true
      client.file_delete('/testing/test')
    end

    it 'must raise a UsageError when given 2 or more args' do
      proc { Commands.mkdir(client, state, ['1', '2']) }.must_raise UsageError
    end
  end

  describe 'when executing the put command' do
    it 'must raise a UsageError when given 0 args' do
      proc { Commands.put(client, state, []) }.must_raise UsageError
    end

    it 'must put a file of the same name when given 1 arg' do
      state.working_dir = '/testing'
      `echo hello > test.txt`
      Commands.put(client, state, ['test.txt'])
      `rm test.txt`
      client.metadata('/testing/test.txt')['is_deleted'].wont_equal true
      client.file_delete('/testing/test.txt')
    end

    it 'must put a file with the stated name when given 2 args' do
      state.working_dir = '/testing'
      `echo hello > test.txt`
      Commands.put(client, state, ['test.txt', 'dest.txt'])
      `rm test.txt`
      client.metadata('/testing/dest.txt')['is_deleted'].wont_equal true
      client.file_delete('/testing/dest.txt')
    end

    it 'must raise a UsageError when given 3 or more args' do
      proc { Commands.put(client, state, [1, 2, 3]) }.must_raise UsageError
    end
  end

  describe 'when executing the rm command' do
    it 'must raise a UsageError when given 0 args' do
      proc { Commands.rm(client, state, []) }.must_raise UsageError
    end

    it 'must remove the remote file when given 1 arg' do
      client.file_create_folder('/testing/test')
      Commands.rm(client, state, ['/testing/test'])
      client.metadata('/testing/test')['is_deleted'].must_equal true
    end

    it 'must raise a UsageError when given 2 or more args' do
      proc { Commands.rm(client, state, ['1', '2']) }.must_raise UsageError
    end
  end
end
