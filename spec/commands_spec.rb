require 'dropbox_sdk'
require 'minitest/autorun'

require_relative 'testutils'
require_relative '../lib/droxi/commands'
require_relative '../lib/droxi/settings'
require_relative '../lib/droxi/state'

describe Commands do
  original_dir = Dir.pwd

  client = DropboxClient.new(Settings[:access_token])
  state = State.new(client)

  TEMP_FILENAME = 'test.txt'
  TEMP_FOLDER = 'test'

  before do
    Dir.chdir(original_dir)
  end

  describe 'when executing a shell command' do
    it 'must yield the output' do
      lines = TestUtils.output_of(Commands, :shell, 'echo test')
      lines.must_equal(['test'])
    end

    it 'must give an error message for an invalid command' do
      lines = TestUtils.output_of(Commands, :shell, 'bogus')
      lines.size.must_equal 1
    end
  end

  describe 'when executing the cat command' do
    before do
      state.pwd = TestUtils::TEST_ROOT
      @cat = proc do |*args|
        capture_io { Commands::CAT.exec(client, state, *args) }
      end
    end

    it 'must print the contents of existing remote files' do
      `echo hello > hello.txt`
      `echo world > world.txt`
      capture_io do
        Commands::PUT.exec(client, state, 'hello.txt', 'world.txt')
      end
      out, _ = @cat.call('hello.txt', 'world.txt')
      out.must_equal("hello\nworld\n")
      `rm hello.txt world.txt`
    end

    it 'must give an error message if trying to cat a bogus file' do
      _, err = @cat.call('bogus')
      err.lines.size.must_equal 1
      err.start_with?('cat: ').must_equal true
    end

    it 'must fail with UsageError when given no args' do
      proc { @cat.call }.must_raise Commands::UsageError
    end
  end

  describe 'when executing the cd command' do
    before do
      @cd = proc do |*args|
        capture_io { Commands::CD.exec(client, state, *args) }
      end
    end

    it 'must change to the root directory when given no args' do
      state.pwd = '/testing'
      @cd.call
      state.pwd.must_equal '/'
    end

    it 'must change to the stated directory when given 1 arg' do
      state.pwd = '/'
      @cd.call('/testing')
      state.pwd.must_equal '/testing'
    end

    it 'must change and set previous directory correctly' do
      state.pwd = '/testing'
      state.pwd = '/'
      @cd.call('-')
      state.pwd.must_equal '/testing'
      state.oldpwd.must_equal '/'
    end

    it 'must not change to a bogus directory' do
      state.pwd = '/'
      @cd.call('/bogus_dir')
      state.pwd.must_equal '/'
    end

    it 'must fail with UsageError when given multiple args' do
      proc { @cd.call('a', 'b') }.must_raise Commands::UsageError
    end
  end

  describe 'when executing the cp command' do
    before do
      state.pwd = TestUtils::TEST_ROOT
      @copy = proc do |*args|
        capture_io { Commands::CP.exec(client, state, *args) }
      end
    end

    it 'must copy source to dest when given 2 args and last arg is non-dir' do
      TestUtils.structure(client, state, 'source')
      TestUtils.not_structure(client, state, 'dest')
      @copy.call('source', 'dest')
      %w(source dest).all? do |dir|
        state.metadata("/testing/#{dir}")
      end.must_equal true
    end

    it 'must copy source into dest when given 2 args and last arg is dir' do
      TestUtils.structure(client, state, 'source', 'dest')
      TestUtils.not_structure(client, state, 'dest/source')
      @copy.call('source', 'dest')
      state.metadata('/testing/dest/source').wont_be_nil
    end

    it 'must copy sources into dest when given 3 or more args' do
      TestUtils.structure(client, state, 'source1', 'source2', 'dest')
      TestUtils.not_structure(client, state, 'dest/source1', 'dest/source2')
      @copy.call('source1', 'source2', 'dest')
      %w(source2 source2).all? do |dir|
        state.metadata("/testing/dest/#{dir}")
      end.must_equal true
    end

    it 'must fail with UsageError when given <2 args' do
      test1 = proc { @copy.call }
      test2 = proc { @copy.call('a') }
      [test1, test2].each { |test| test.must_raise Commands::UsageError }
    end

    it 'must give an error message if trying to copy a bogus file' do
      _, err = @copy.call('bogus', '/testing')
      err.lines.size.must_equal 1
      err.start_with?('cp: ').must_equal true
    end

    it 'must fail to overwrite file without -f flag' do
      TestUtils.structure(client, state, 'source.txt', 'dest.txt')
      _, err = @copy.call('source.txt', 'dest.txt')
      err.lines.size.must_equal 1
    end

    it 'must also cp normally with -f flag' do
      TestUtils.structure(client, state, 'source.txt')
      TestUtils.not_structure(client, state, 'dest.txt')
      _, err = @copy.call('-f', 'source.txt', 'dest.txt')
      err.must_be :empty?
    end
  end

  describe 'when executing the debug command' do
    before do
      @debug = proc do |*args|
        capture_io { Commands::DEBUG.exec(client, state, *args) }
      end
    end

    it 'must fail with an error message if debug mode is not enabled' do
      ARGV.clear
      _, err = @debug.call('1')
      err.lines.size.must_equal 1
      err.start_with?('debug: ').must_equal true
    end

    it 'must evaluate the string if debug mode is enabled' do
      ARGV << '--debug'
      out, _ = @debug.call('1')
      out.must_equal("1\n")
    end

    it 'must handle syntax errors' do
      ARGV << '--debug'
      _, err = @debug.call('"x')
      err.lines.size.must_equal 1
    end

    it 'must print the resulting exception if given exceptional input' do
      ARGV << '--debug'
      _, err = @debug.call('x')
      err.lines.size.must_equal 1
      err.must_match(/^#<.+>$/)
    end

    it 'must fail with UsageError when given no args' do
      proc { @debug.call }.must_raise Commands::UsageError
    end
  end

  describe 'when executing the forget command' do
    it 'must clear entire cache when given no arguments' do
      capture_io { Commands::LS.exec(client, state, '/') }
      Commands::FORGET.exec(client, state)
      state.cache.empty?.must_equal true
    end

    it 'must accept multiple arguments' do
      args = %w(bogus1, bogus2)
      _, err = capture_io { Commands::FORGET.exec(client, state, *args) }
      err.lines.size.must_equal 2
    end

    it 'must recursively clear contents of directory argument' do
      capture_io { Commands::LS.exec(client, state, '/', '/testing') }
      Commands::FORGET.exec(client, state, '/')
      state.cache.size.must_equal 1
    end
  end

  describe 'when executing the get command' do
    before do
      state.pwd = TestUtils::TEST_ROOT
      @get = proc do |*args|
        capture_io { Commands::GET.exec(client, state, *args) }
      end
    end

    it 'must get a file of the same name when given args' do
      TestUtils.structure(client, state, 'test.txt')
      @get.call('test.txt')
      `ls test.txt`.chomp.must_equal 'test.txt'
      `rm test.txt`
    end

    it 'must fail with UsageError when given no args' do
      proc { @get.call }.must_raise Commands::UsageError
    end

    it 'must give an error message if trying to get a bogus file' do
      _, err = @get.call('bogus')
      err.lines.size.must_equal 1
      err[/^get: /].wont_be_nil
    end

    it 'must fail if trying to get existing file without -f' do
      TestUtils.structure(client, state, 'test.txt')
      `touch test.txt`
      _, err = @get.call('test.txt')
      err.lines.size.must_equal 1
      err[/^get: /].wont_be_nil
    end

    it 'must not fail if trying to get existing file with -f' do
      TestUtils.structure(client, state, 'test.txt')
      `touch test.txt`
      _, err = @get.call('-f', 'test.txt')
      err.must_be :empty?
    end
  end

  describe 'when executing the lcd command' do
    it 'must change to home directory when given no args' do
      prev_pwd = Dir.pwd
      Commands::LCD.exec(client, state)
      Dir.pwd.must_equal File.expand_path('~')
      Dir.chdir(prev_pwd)
    end

    it 'must change to specific directory when specified' do
      prev_pwd = Dir.pwd
      Commands::LCD.exec(client, state, '/home')
      Dir.pwd.must_equal File.expand_path('/home')
      Dir.chdir(prev_pwd)
    end

    it 'must set oldpwd correctly' do
      oldpwd = Dir.pwd
      Commands::LCD.exec(client, state, '/')
      state.local_oldpwd.must_equal oldpwd
      Dir.chdir(oldpwd)
    end

    it 'must change to previous directory when given -' do
      oldpwd = Dir.pwd
      Commands::LCD.exec(client, state, '/')
      Commands::LCD.exec(client, state, '-')
      Dir.pwd.must_equal oldpwd
      Dir.chdir(oldpwd)
    end

    it 'must fail if given bogus directory name' do
      pwd = Dir.pwd
      oldpwd = state.local_oldpwd
      capture_io { Commands::LCD.exec(client, state, '/bogus_dir') }
      Dir.pwd.must_equal pwd
      state.local_oldpwd.must_equal oldpwd
      Dir.chdir(pwd)
    end
  end

  describe 'when executing the ls command' do
    before do
      @ls = proc do |*args|
        capture_io { Commands::LS.exec(client, state, *args) }
      end
    end

    it 'must list the working directory contents when given no args' do
      TestUtils.exact_structure(client, state, 'test')
      state.pwd = '/testing'
      out, _ = @ls.call
      out.must_equal("test  \n")
    end

    it 'must list the stated directory contents when given args' do
      state.pwd = '/'
      TestUtils.exact_structure(client, state, 'test')
      out, _ = @ls.call('/testing')
      out.must_equal("test  \n")
    end

    it 'must give a longer description with the -l option' do
      state.pwd = '/'
      TestUtils.exact_structure(client, state, 'test')
      out, _ = @ls.call('-l', '/testing')
      out.lines.size.must_equal 1
      out[/^d +0 \w{3} .\d \d\d:\d\d test$/].wont_be_nil
    end

    it 'must give an error message if trying to list a bogus file' do
      _, err = @ls.call('bogus')
      err.lines.size.must_equal 1
      err.start_with?('ls: ').must_equal true
    end
  end

  describe 'when executing the media command' do
    before do
      @media = proc do |*args|
        capture_io { Commands::MEDIA.exec(client, state, *args) }
      end
    end

    it 'must yield URL when given file path' do
      TestUtils.structure(client, state, 'test.txt')
      path = '/testing/test.txt'
      out, _ = @media.call(path)
      out.lines.size.must_equal 1
      %r{https://.+\..+/}.match(out).wont_be_nil
    end

    it 'must fail with error when given directory path' do
      _, err = @media.call('/testing')
      err.lines.size.must_equal 1
      %r{https://.+\..+/}.match(err).must_be_nil
    end

    it 'must fail with UsageError when given no args' do
      proc { @media.call }.must_raise Commands::UsageError
    end

    it 'must give an error message if trying to link a bogus file' do
      _, err = @media.call('%')
      err.lines.size.must_equal 1
      err.start_with?('media: ').must_equal true
    end
  end

  describe 'when executing the mkdir command' do
    it 'must create a directory when given args' do
      TestUtils.not_structure(client, state, 'test')
      Commands::MKDIR.exec(client, state, '/testing/test')
      state.metadata('/testing/test').wont_be_nil
    end

    it 'must fail with UsageError when given no args' do
      proc { Commands::MKDIR.exec(client, state) }
        .must_raise Commands::UsageError
    end
  end

  describe 'when executing the mv command' do
    before do
      state.pwd = TestUtils::TEST_ROOT
      @move = proc do |*args|
        capture_io { Commands::MV.exec(client, state, *args) }
      end
    end

    it 'must move source to dest when given 2 args and last arg is non-dir' do
      TestUtils.structure(client, state, 'source')
      TestUtils.not_structure(client, state, 'dest')
      @move.call('source', 'dest')
      state.metadata('/testing/source').must_be_nil
      state.metadata('/testing/dest').wont_be_nil
    end

    it 'must move source into dest when given 2 args and last arg is dir' do
      TestUtils.structure(client, state, 'source', 'dest')
      TestUtils.not_structure(client, state, 'dest/source')
      @move.call('source', 'dest')
      state.metadata('/testing/source').must_be_nil
      state.metadata('/testing/dest/source').wont_be_nil
    end

    it 'must move sources into dest when given 3 or more args' do
      TestUtils.structure(client, state, 'source1', 'source2', 'dest')
      TestUtils.not_structure(client, state, 'dest/source1', 'dest/source2')
      @move.call('source1', 'source2', 'dest')
      %w(source2 source2).all? do |dir|
        state.metadata("/testing/#{dir}").must_be_nil
        state.metadata("/testing/dest/#{dir}")
      end.must_equal true
    end

    it 'must fail with UsageError when given <2 args' do
      test1 = proc { @move.call }
      test2 = proc { @move.call('a') }
      [test1, test2].each { |test| test.must_raise Commands::UsageError }
    end

    it 'must give an error message if trying to move a bogus file' do
      _, err = @move.call('bogus1', 'bogus2', 'bogus3')
      err.lines.size.must_equal 3
      err.lines.all? { |line| line.start_with?('mv: ') }.must_equal true
    end

    it 'must fail to overwrite file without -f flag' do
      TestUtils.structure(client, state, 'source.txt', 'dest.txt')
      _, err = @move.call('source.txt', 'dest.txt')
      err.lines.size.must_equal 1
    end

    it 'must overwrite with -f flag' do
      TestUtils.structure(client, state, 'source.txt', 'dest.txt')
      _, err = @move.call('-f', 'source.txt', 'dest.txt')
      err.must_be :empty?
      state.metadata('/testing/source.txt').must_be_nil
    end
  end

  describe 'when executing the put command' do
    before do
      state.pwd = TestUtils::TEST_ROOT
      @put = proc do |*args|
        capture_io { Commands::PUT.exec(client, state, *args) }
      end
    end

    it 'must put multiple files' do
      TestUtils.not_structure(client, state, 'file1.txt', 'file2.txt')
      `touch file1.txt file2.txt`
      @put.call('file1.txt', 'file2.txt')
      `rm file1.txt file2.txt`
      state.metadata('/testing/file1.txt').wont_be_nil
      state.metadata('/testing/file2.txt').wont_be_nil
    end

    it 'must not overwrite without -f option' do
      TestUtils.structure(client, state, 'test.txt')
      TestUtils.not_structure(client, state, 'test (1).txt')
      `touch test.txt`
      @put.call('test.txt')
      `rm test.txt`
      state.metadata('/testing/test (1).txt').wont_be_nil
    end

    it 'must overwrite with -f option' do
      TestUtils.structure(client, state, 'test.txt')
      TestUtils.not_structure(client, state, 'test (1).txt')
      `touch test.txt`
      @put.call('-f', 'test.txt')
      `rm test.txt`
      state.metadata('/testing/test (1).txt').must_be_nil
    end

    it 'must fail with UsageError when given no args' do
      proc { @put.call }.must_raise Commands::UsageError
    end
  end

  describe 'when executing the share command' do
    before do
      @share = proc do |*args|
        capture_io { Commands::SHARE.exec(client, state, *args) }
      end
    end

    it 'must yield URL when given file path' do
      TestUtils.structure(client, state, 'test.txt')
      out, _ = @share.call('/testing/test.txt')
      out.lines.size.must_equal 1
      %r{https://.+\..+/}.match(out).wont_be_nil
    end

    it 'must fail with UsageError when given no args' do
      proc { @share.call }.must_raise Commands::UsageError
    end

    it 'must give an error message if trying to share a bogus file' do
      _, err = @share.call('%')
      err.lines.size.must_equal 1
      err.start_with?('share: ').must_equal true
    end
  end

  describe 'when executing the rm command' do
    before do
      @rm = proc do |*args|
        capture_io { Commands::RM.exec(client, state, *args) }
      end
    end

    it 'must remove the remote file when given args' do
      TestUtils.structure(client, state, 'test.txt')
      @rm.call('/testing/test.txt')
      state.metadata('/testing/test.txt').must_be_nil
    end

    it 'must change pwd to existing dir if the current one is removed' do
      # FIXME: I don't know why this test fails. It works in practice.
      # TestUtils.structure(client, state, 'one', 'one/two')
      # Commands::CD.exec(client, state, '/testing/one/two')
      # Commands::RM.exec(client, state, '..')
      # state.pwd.must_equal('/testing')
    end

    it 'must fail with UsageError when given no args' do
      proc { @rm.call }.must_raise Commands::UsageError
    end

    it 'must give an error message if trying to remove a bogus file' do
      _, err = @rm.call('bogus')
      err.lines.size.must_equal 1
      err.start_with?('rm: ').must_equal true
    end

    it 'must give error message if trying to remove dir without -r option' do
      TestUtils.structure(client, state, 'test')
      _, err = @rm.call('/testing/test')
      err.lines.size.must_equal 1
      err.start_with?('rm: ').must_equal true
    end

    it 'must remove dir recursively when given -r option' do
      TestUtils.structure(client, state, 'test', 'test/dir', 'test/file.txt')
      @rm.call('-r', '/testing/test')
      paths = %w(/testing/test /testing/test/dir /testing/test/file.txt)
      paths.each { |path| state.metadata(path).must_be_nil }
    end
  end

  describe 'when executing the help command' do
    before do
      @help = proc do |*args|
        capture_io { Commands::HELP.exec(client, state, *args) }
      end
    end

    it 'must print a list of commands when given no args' do
      out, _ = @help.call
      out.split.size.must_equal Commands::NAMES.size
    end

    it 'must print help for a command when given it as an arg' do
      out, _ = @help.call('help')
      out.lines.size.must_be :>=, 2
      out.lines.first.chomp.must_equal Commands::HELP.usage
      out.lines.drop(1).join(' ').tr("\n", '')
        .must_equal Commands::HELP.description
    end

    it 'must print an error message if given a bogus name as an arg' do
      _, err = @help.call('bogus')
      err.lines.size.must_equal 1
      err.start_with?('help: ').must_equal true
    end

    it 'must fail with UsageError when given multiple args' do
      proc { @help.call('a', 'b') }.must_raise Commands::UsageError
    end
  end

  describe 'when executing the rmdir command' do
    before do
      @rmdir = proc do |*args|
        capture_io { Commands::RMDIR.exec(client, state, *args) }
      end
    end

    it 'must remove remote directories if empty' do
      TestUtils.exact_structure(client, state, 'dir1', 'dir2')
      Commands::RMDIR.exec(client, state, '/testing/dir?')
      paths = %w(/testing/dir1 /testing/dir2)
      paths.each { |path| state.metadata(path).must_be_nil }
    end

    it 'must fail with error if remote directory not empty' do
      TestUtils.structure(client, state, 'test', 'test/subtest')
      _, err = @rmdir.call('/testing/test')
      err.lines.size.must_equal 1
      err.start_with?('rmdir: ').must_equal true
    end

    it 'must fail with error if used on file' do
      TestUtils.structure(client, state, 'test.txt')
      _, err = @rmdir.call('/testing/test.txt')
      err.lines.size.must_equal 1
      err.start_with?('rmdir: ').must_equal true
    end

    it 'must fail with error if given bogus name' do
      TestUtils.not_structure(client, state, 'bogus')
      _, err = @rmdir.call('/testing/bogus')
      err.lines.size.must_equal 1
      err.start_with?('rmdir: ').must_equal true
    end

    it 'must fail with UsageError when given no args' do
      proc { @rmdir.call }.must_raise Commands::UsageError
    end
  end

  describe 'when executing the exit command' do
    it 'must request exit when given no args' do
      Commands::EXIT.exec(client, state)
      state.exit_requested.must_equal true
      state.exit_requested = false
    end

    it 'must fail with UsageError when given args' do
      proc { Commands::EXIT.exec(client, state, 'a') }
        .must_raise Commands::UsageError
    end
  end

  describe 'when exec-ing a string' do
    it 'must call a shell command when beginning with a !' do
      proc { Commands.exec('!echo hello', client, state) }
        .must_output "hello\n"
    end

    it "must execute a command when given the command's name" do
      _, err = capture_io { Commands.exec('lcd ~bogus', client, state) }
      err.must_equal "lcd: ~bogus: no such file or directory\n"
    end

    it 'must do nothing when given an empty string' do
      proc { Commands.exec('', client, state) }.must_be_silent
    end

    it 'must handle backslash-escaped spaces correctly' do
      TestUtils.structure(client, state, 'folder with spaces')
      proc { Commands.exec('ls /testing/folder\ with\ spaces', client, state) }
        .must_be_silent
    end

    it 'must give a usage error message for incorrect arg count' do
      _, err = capture_io { Commands.exec('get', client, state) }
      err.start_with?('Usage: ').must_equal true
    end

    it 'must give an error message for invalid command name' do
      _, err = capture_io { Commands.exec('drink soda', client, state) }
      err.start_with?('droxi: ').must_equal true
    end
  end

  describe 'when querying argument type' do
    it 'must return nil for command without args' do
      Commands::EXIT.type_of_arg(1).must_be_nil
    end

    it 'must return correct types for in-bounds indices' do
      Commands::MV.type_of_arg(0).must_equal 'REMOTE_FILE'
      Commands::MV.type_of_arg(1).must_equal 'REMOTE_FILE'
    end

    it 'must return last types for out-of-bounds index' do
      Commands::PUT.type_of_arg(3).must_equal 'LOCAL_FILE'
    end
  end
end
