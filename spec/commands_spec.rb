require 'dropbox_sdk'
require 'minitest/autorun'

require_relative '../lib/droxi/commands'
require_relative '../lib/droxi/settings'
require_relative '../lib/droxi/state'

def ignore(error_class)
  yield
rescue error_class
  nil
end

def put_temp_file(client, state)
  `echo hello > #{TEMP_FILENAME}`
  Commands::PUT.exec(client, state, TEMP_FILENAME,
                     "/#{TEST_FOLDER}/#{TEMP_FILENAME}")
  `rm #{TEMP_FILENAME}`
end

def delete_temp_file(client, state)
  Commands::RM.exec(client, state, "/#{TEST_FOLDER}/#{TEMP_FILENAME}")
end

def get_output(cmd, client, state, *args)
  lines = []
  Commands.const_get(cmd).exec(client, state, *args) { |line| lines << line }
  lines
end

describe Commands do
  original_dir = Dir.pwd

  client = DropboxClient.new(Settings[:access_token])
  state = State.new(client)

  TEMP_FILENAME = 'test.txt'
  TEMP_FOLDER = 'test'
  TEST_FOLDER = 'testing'

  ignore(DropboxError) { client.file_delete("/#{TEST_FOLDER}") }
  ignore(DropboxError) { client.file_create_folder("/#{TEST_FOLDER}") }

  before do
    Dir.chdir(original_dir)
  end

  describe 'when executing a shell command' do
    it 'must yield the output' do
      lines = []
      Commands.shell('echo testing') { |line| lines << line }
      lines.must_equal(['testing'])
    end
  end

  describe 'when executing the cd command' do
    it 'must change to the root directory when given no args' do
      state.pwd = '/testing'
      Commands::CD.exec(client, state)
      state.pwd.must_equal '/'
    end

    it 'must change to the previous directory when given -' do
      state.pwd = '/testing'
      state.pwd = '/'
      Commands::CD.exec(client, state, '-')
      state.pwd.must_equal '/testing'
    end

    it 'must change to the stated directory when given 1 arg' do
      state.pwd = '/'
      Commands::CD.exec(client, state, '/testing')
      state.pwd.must_equal '/testing'
    end

    it 'must set previous directory correctly' do
      state.pwd = '/testing'
      state.pwd = '/'
      Commands::CD.exec(client, state, '/testing')
      state.oldpwd.must_equal '/'
    end

    it 'must not change to a bogus directory' do
      state.pwd = '/'
      Commands::CD.exec(client, state, '/bogus_dir')
      state.pwd.must_equal '/'
    end

    it 'must fail with UsageError when given multiple args' do
      test = proc { Commands::CD.exec(client, state, 'a', 'b') }
      test.must_raise Commands::UsageError
    end
  end

  describe 'when executing the cp command' do
    before do
      state.pwd = '/testing'
    end

    after do
      Commands::RM.exec(client, state, '*')
    end

    it 'must copy source to dest when given 2 args and last arg is non-dir' do
      Commands::MKDIR.exec(client, state, 'source')
      Commands::CP.exec(client, state, 'source', 'dest')
      %w(source dest).all? do |dir|
        client.metadata("/testing/#{dir}")
      end.must_equal true
    end

    it 'must copy source into dest when given 2 args and last arg is dir' do
      Commands::MKDIR.exec(client, state, 'source', 'dest')
      Commands::CP.exec(client, state, 'source', 'dest')
      client.metadata('/testing/dest/source').wont_equal nil
    end

    it 'must copy sources into dest when given 3 or more args' do
      Commands::MKDIR.exec(client, state, 'source1', 'source2', 'dest')
      Commands::CP.exec(client, state, 'source1', 'source2', 'dest')
      %w(source2 source2).all? do |dir|
        client.metadata("/testing/dest/#{dir}")
      end.must_equal true
    end

    it 'must fail with UsageError when given <2 args' do
      test1 = proc { Commands::CP.exec(client, state) }
      test2 = proc { Commands::CP.exec(client, state, 'a') }
      [test1, test2].each { |test| test.must_raise Commands::UsageError }
    end
  end

  describe 'when executing the forget command' do
    it 'must clear entire cache when given no arguments' do
      Commands::LS.exec(client, state, '/')
      Commands::FORGET.exec(client, state)
      state.cache.empty?.must_equal true
    end

    it 'must accept multiple arguments' do
      lines = []
      Commands::FORGET.exec(client, state, 'bogus1', 'bogus2') do |line|
        lines << line
      end
      lines.length.must_equal 2
    end

    it 'must recursively clear contents of directory argument' do
      Commands::LS.exec(client, state, '/', '/testing')
      Commands::FORGET.exec(client, state, '/')
      state.cache.length.must_equal 1
    end
  end

  describe 'when executing the get command' do
    it 'must get a file of the same name when given args' do
      put_temp_file(client, state)
      Commands::GET.exec(client, state, '/testing/test.txt')
      delete_temp_file(client, state)
      `ls test.txt`.chomp.must_equal 'test.txt'
      `rm test.txt`
    end

    it 'must fail with UsageError when given no args' do
      test = proc { Commands::GET.exec(client, state) }
      test.must_raise Commands::UsageError
    end
  end

  describe 'when executing the lcd command' do
    it 'must change to home directory when given no args' do
      Commands::LCD.exec(client, state)
      Dir.pwd.must_equal File.expand_path('~')
    end

    it 'must change to specific directory when specified' do
      Commands::LCD.exec(client, state, '/home')
      Dir.pwd.must_equal File.expand_path('/home')
    end

    it 'must set oldpwd correctly' do
      oldpwd = Dir.pwd
      Commands::LCD.exec(client, state, '/')
      state.local_oldpwd.must_equal oldpwd
    end

    it 'must change to previous directory when given -' do
      oldpwd = Dir.pwd
      Commands::LCD.exec(client, state, '/')
      Commands::LCD.exec(client, state, '-')
      Dir.pwd.must_equal oldpwd
    end

    it 'must fail if given bogus directory name' do
      pwd = Dir.pwd
      oldpwd = state.local_oldpwd
      Commands::LCD.exec(client, state, '/bogus_dir')
      Dir.pwd.must_equal pwd
      state.local_oldpwd.must_equal oldpwd
    end
  end

  describe 'when executing the ls command' do
    it 'must list the working directory contents when given no args' do
      Commands::MKDIR.exec(client, state, '/testing/test')
      state.pwd = '/testing'
      lines = []
      Commands::LS.exec(client, state) { |line| lines << line }
      lines.must_equal(['test  '])
      Commands::RM.exec(client, state, '/testing/test')
    end

    it 'must list the stated directory contents when given args' do
      state.pwd = '/'
      Commands::MKDIR.exec(client, state, '/testing/test')
      lines = []
      Commands::LS.exec(client, state, '/testing') { |line| lines << line }
      lines.must_equal(['test  '])
      Commands::RM.exec(client, state, '/testing/test')
    end

    it 'must give a longer description with the -l option' do
      state.pwd = '/'
      Commands::MKDIR.exec(client, state, '/testing/test')
      lines = []
      Commands::LS.exec(client, state, '-l', '/testing') do |line|
        lines << line
      end
      lines.length.must_equal 1
      /d +0 \w{3} .\d \d\d:\d\d test/.match(lines[0]).wont_equal nil
      Commands::RM.exec(client, state, '/testing/test')
    end
  end

  describe 'when executing the media command' do
    it 'must yield URL when given file path' do
      put_temp_file(client, state)
      to_path = "/#{TEST_FOLDER}/#{TEMP_FILENAME}"
      lines = get_output(:MEDIA, client, state, to_path)
      delete_temp_file(client, state)
      lines.length.must_equal 1
      %r{https://.+\..+/}.match(lines[0]).wont_equal nil
    end

    it 'must fail with UsageError when given no args' do
      test = proc { Commands::MEDIA.exec(client, state) }
      test.must_raise Commands::UsageError
    end
  end

  describe 'when executing the mkdir command' do
    it 'must create a directory when given args' do
      Commands::MKDIR.exec(client, state, '/testing/test')
      client.metadata('/testing/test')['is_deleted'].wont_equal true
      Commands::RM.exec(client, state, '/testing/test')
    end

    it 'must fail with UsageError when given no args' do
      test = proc { Commands::MKDIR.exec(client, state) }
      test.must_raise Commands::UsageError
    end
  end

  describe 'when executing the mv command' do
    before do
      state.pwd = '/testing'
    end

    after do
      Commands::RM.exec(client, state, '*')
    end

    it 'must move source to dest when given 2 args and last arg is non-dir' do
      Commands::MKDIR.exec(client, state, 'source')
      Commands::MV.exec(client, state, 'source', 'dest')
      client.metadata('/testing/source')['is_deleted'].must_equal true
      client.metadata('/testing/dest').wont_equal nil
    end

    it 'must move source into dest when given 2 args and last arg is dir' do
      Commands::MKDIR.exec(client, state, 'source', 'dest')
      Commands::MV.exec(client, state, 'source', 'dest')
      client.metadata('/testing/source')['is_deleted'].must_equal true
      client.metadata('/testing/dest/source').wont_equal nil
    end

    it 'must move sources into dest when given 3 or more args' do
      Commands::MKDIR.exec(client, state, 'source1', 'source2', 'dest')
      Commands::MV.exec(client, state, 'source1', 'source2', 'dest')
      %w(source2 source2).all? do |dir|
        client.metadata("/testing/#{dir}")['is_deleted'].must_equal true
        client.metadata("/testing/dest/#{dir}")
      end.must_equal true
    end

    it 'must fail with UsageError when given <2 args' do
      test1 = proc { Commands::MV.exec(client, state) }
      test2 = proc { Commands::MV.exec(client, state, 'a') }
      [test1, test2].each { |test| test.must_raise Commands::UsageError }
    end
  end

  describe 'when executing the put command' do
    it 'must put a file of the same name when given 1 arg' do
      state.pwd = '/testing'
      `echo hello > test.txt`
      Commands::PUT.exec(client, state, 'test.txt')
      `rm test.txt`
      client.metadata('/testing/test.txt')['is_deleted'].wont_equal true
      Commands::RM.exec(client, state, '/testing/test.txt')
    end

    it 'must put a file with the stated name when given 2 args' do
      state.pwd = '/testing'
      `echo hello > test.txt`
      Commands::PUT.exec(client, state, 'test.txt', 'dest.txt')
      `rm test.txt`
      client.metadata('/testing/dest.txt')['is_deleted'].wont_equal true
      Commands::RM.exec(client, state, '/testing/dest.txt')
    end

    it 'must fail with UsageError when given no args' do
      test = proc { Commands::PUT.exec(client, state) }
      test.must_raise Commands::UsageError
    end
  end

  describe 'when executing the share command' do
    it 'must yield URL when given file path' do
      put_temp_file(client, state)
      to_path = "/#{TEST_FOLDER}/#{TEMP_FILENAME}"
      lines = get_output(:SHARE, client, state, to_path)
      delete_temp_file(client, state)
      lines.length.must_equal 1
      %r{https://.+\..+/}.match(lines[0]).wont_equal nil
    end

    it 'must fail with UsageError when given no args' do
      test = proc { Commands::SHARE.exec(client, state) }
      test.must_raise Commands::UsageError
    end
  end

  describe 'when executing the rm command' do
    it 'must remove the remote file when given args' do
      Commands::MKDIR.exec(client, state, '/testing/test')
      Commands::RM.exec(client, state, '/testing/test')
      client.metadata('/testing/test')['is_deleted'].must_equal true
    end

    it 'must change pwd to existing dir if the current one is removed' do
      Commands::MKDIR.exec(client, state, '/testing/one')
      Commands::MKDIR.exec(client, state, '/testing/one/two')
      Commands::CD.exec(client, state, '/testing/one/two')
      Commands::RM.exec(client, state, '..')
      state.pwd.must_equal('/testing')
    end

    it 'must fail with UsageError when given no args' do
      test = proc { Commands::RM.exec(client, state) }
      test.must_raise Commands::UsageError
    end
  end

  describe 'when executing the help command' do
    it 'must print a list of commands when given no args' do
      lines = []
      Commands::HELP.exec(client, state) { |line| lines << line }
      lines.join.split.length.must_equal Commands::NAMES.length
    end

    it 'must print help for a command when given it as an arg' do
      lines = []
      Commands::HELP.exec(client, state, 'help') { |line| lines << line }
      lines.length.must_be :>=, 2
      lines[0].must_equal Commands::HELP.usage
      lines.drop(1).join(' ').must_equal Commands::HELP.description
    end

    it 'must print an error message if given a bogus name as an arg' do
      lines = []
      Commands::HELP.exec(client, state, 'bogus') { |line| lines << line }
      lines.length.must_equal 1
    end

    it 'must fail with UsageError when given multiple args' do
      test = proc { Commands::HELP.exec(client, state, 'a', 'b') }
      test.must_raise Commands::UsageError
    end
  end

  describe 'when executing the exit command' do
    it 'must request exit when given no args' do
      Commands::EXIT.exec(client, state)
      state.exit_requested.must_equal true
      state.exit_requested = false
    end

    it 'must fail with UsageError when given args' do
      test = proc { Commands::EXIT.exec(client, state, 'a') }
      test.must_raise Commands::UsageError
    end
  end

  describe 'when exec-ing a string' do
    it 'must call a shell command when beginning with a !' do
      test = proc { Commands.exec('!echo hello', client, state) }
      test.must_output "hello\n"
    end

    it "must execute a command when given the command's name" do
      test = proc { Commands.exec('lcd ~bogus', client, state) }
      test.must_output "lcd: ~bogus: no such file or directory\n"
    end

    it 'must do nothing when given an empty string' do
      test = proc { Commands.exec('', client, state) }
      test.must_be_silent
    end
  end

  describe 'when querying argument type' do
    it 'must return nil for command without args' do
      Commands::EXIT.type_of_arg(1).must_be_nil
    end

    it 'must return correct types for in-bounds indices' do
      Commands::PUT.type_of_arg(0).must_equal 'LOCAL_FILE'
      Commands::PUT.type_of_arg(1).must_equal 'REMOTE_FILE'
    end

    it 'must return last types for out-of-bounds index' do
      Commands::PUT.type_of_arg(3).must_equal 'REMOTE_FILE'
    end
  end
end
