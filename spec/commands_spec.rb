require 'dropbox_sdk'
require 'minitest/autorun'

require_relative '../commands'
require_relative '../settings'
require_relative '../state'

client = DropboxClient.new(Settings[:access_token])
state = State.new

TEMP_FILENAME = 'test.txt'
TEMP_FOLDER = 'test'
TEST_FOLDER = 'testing'

begin
  client.file_create_folder("/#{TEST_FOLDER}")
rescue DropboxError
end

def put_temp_file(client)
  `echo hello > #{TEMP_FILENAME}`
  open(TEMP_FILENAME, 'rb') do |file|
    client.put_file("/#{TEST_FOLDER}/#{TEMP_FILENAME}", file)
  end
  `rm test.txt`
end

def delete_temp_file(client)
  client.file_delete("/#{TEST_FOLDER}/#{TEMP_FILENAME}")
end

def get_output(method, client, state, args)
  lines = []
  Commands.send(method, client, state, args) { |line| lines << line }
  lines
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
      state.pwd = '/testing'
      Commands.cd(client, state, [])
      state.pwd.must_equal '/'
    end

    it 'must change to the previous directory when given -' do
      state.pwd = '/testing'
      state.pwd = '/'
      Commands.cd(client, state, ['-'])
      state.pwd.must_equal '/testing'
    end

    it 'must change to the stated directory when given 1 arg' do
      state.pwd = '/'
      Commands.cd(client, state, ['/testing'])
      state.pwd.must_equal '/testing'
    end

    it 'must set previous directory correctly' do
      state.pwd = '/testing'
      state.pwd = '/'
      Commands.cd(client, state, ['/testing'])
      state.oldpwd.must_equal '/'
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
      state.pwd = '/testing'
      lines = []
      Commands.ls(client, state, []) { |line| lines << line }
      lines.must_equal(['test'])
      client.file_delete('/testing/test')
    end

    it 'must list the stated directory contents when given 1 arg' do
      state.pwd = '/'
      client.file_create_folder('/testing/test')
      lines = []
      Commands.ls(client, state, ['/testing']) { |line| lines << line }
      lines.must_equal(['test'])
      client.file_delete('/testing/test')
    end
  end

  describe 'when executing the mkdir command' do
    it 'must raise a UsageError when given no args' do
      proc { Commands.mkdir(client, state, []) }.must_raise UsageError
    end

    it 'must create a directory when given args' do
      Commands.mkdir(client, state, ['/testing/test'])
      client.metadata('/testing/test')['is_deleted'].wont_equal true
      client.file_delete('/testing/test')
    end
  end

  describe 'when executing the put command' do
    it 'must raise a UsageError when given 0 args' do
      proc { Commands.put(client, state, []) }.must_raise UsageError
    end

    it 'must put a file of the same name when given 1 arg' do
      state.pwd = '/testing'
      `echo hello > test.txt`
      Commands.put(client, state, ['test.txt'])
      `rm test.txt`
      client.metadata('/testing/test.txt')['is_deleted'].wont_equal true
      client.file_delete('/testing/test.txt')
    end

    it 'must put a file with the stated name when given 2 args' do
      state.pwd = '/testing'
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

  describe 'when executing the share command' do
    it 'must raise UsageError when given no args' do
      proc { Commands.share(client, state, []) }.must_raise UsageError
    end

    it 'must yield URL when given file path' do
      put_temp_file(client)
      to_path = "/#{TEST_FOLDER}/#{TEMP_FILENAME}"
      lines = get_output(:share, client, state, [to_path])
      delete_temp_file(client)
      lines.length.must_equal 1
      /https:\/\/.+\..+\//.match(lines[0]).wont_equal nil
    end
  end

  describe 'when executing the rm command' do
    it 'must raise a UsageError when given no args' do
      proc { Commands.rm(client, state, []) }.must_raise UsageError
    end

    it 'must remove the remote file when given args' do
      client.file_create_folder('/testing/test')
      Commands.rm(client, state, ['/testing/test'])
      client.metadata('/testing/test')['is_deleted'].must_equal true
    end
  end
end
