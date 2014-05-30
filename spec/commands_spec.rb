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
      Commands.cd(client, state, ['/testing'])
      Commands.cd(client, state, [])
      state.working_dir.must_equal '/'
    end

    it 'must change to the stated directory when given 1 arg' do
      Commands.cd(client, state, [])
      Commands.cd(client, state, ['/testing'])
      state.working_dir.must_equal '/testing'
    end

    it 'must raise a UsageError when given 2 or more args' do
      proc { Commands.cd(client, state, ['1', '2']) }.must_raise UsageError
    end
  end

  describe 'when executing the ls command' do
    it 'must list the working directory contents when given 0 args' do
      Commands.cd(client, state, ['/testing'])
      lines = []
      Commands.ls(client, state, []) { |line| lines << line }
      lines.must_equal(['LICENSE'])
    end

    it 'must list the stated directory contents when given 1 arg' do
      Commands.cd(client, state, [])
      lines = []
      Commands.ls(client, state, ['/testing']) { |line| lines << line }
      lines.must_equal(['LICENSE'])
    end

    it 'must raise a UsageError when given 2 or more args' do
      proc { Commands.ls(client, state, ['1', '2']) }.must_raise UsageError
    end
  end
end
