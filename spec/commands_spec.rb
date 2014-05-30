require 'dropbox_sdk'
require 'minitest/autorun'

require_relative '../commands'
require_relative '../settings'

client = DropboxClient.new(Settings[:access_token])
state = Struct.new(:working_dir).new('/')

describe Commands do
  describe 'when executing a shell command' do
    it 'must print the output' do
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

  describe 'when executing the ls command' do
    it 'must list the working directory contents when given 0 args' do
      state.working_dir = '/testing'
      lines = []
      Commands.ls(client, state, []) { |line| lines << line }
      lines.must_equal(['LICENSE'])
    end

    it 'must list the stated directory contents when given 1 arg' do
      lines = []
      Commands.ls(client, state, ['/testing']) { |line| lines << line }
      lines.must_equal(['LICENSE'])
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
