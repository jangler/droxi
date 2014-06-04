require 'time'

require_relative 'text'

# Module containing definitions for client commands.
module Commands

  # Exception indicating that a client command was given the wrong number of
  # arguments.
  class UsageError < ArgumentError
  end

  # A client command. Contains metadata as well as execution procedure.
  class Command

    # A +String+ specifying the usage of the command in the style of a man page
    # synopsis. Optional arguments are enclosed in brackets; varargs-style
    # arguments are suffixed with an ellipsis.
    attr_reader :usage

    # A complete description of the command, suitable for display to the end
    # user.
    attr_reader :description

    # Create a new +Command+ with the given metadata and a +Proc+ specifying
    # its behavior. The +Proc+ will receive four arguments: the
    # +DropboxClient+, the +State+, an +Array+ of command-line arguments, and
    # a +Proc+ to be called for output.
    def initialize(usage, description, procedure)
      @usage = usage
      @description = description.squeeze(' ')
      @procedure = procedure
    end

    # Attempt to execute the +Command+, yielding lines of output if a block is
    # given. Raises a +UsageError+ if an invalid number of command-line
    # arguments is given.
    def exec(client, state, *args)
      if num_args_ok?(args.length)
        block = proc { |line| yield line if block_given? }
        @procedure.yield(client, state, args, block)
      else
        fail UsageError, @usage
      end
    end

    # Return a +String+ describing the type of argument at the given index.
    # If the index is out of range, return the type of the final argument. If
    # the +Command+ takes no arguments, return +nil+.
    def type_of_arg(index)
      args = @usage.split.drop(1).reject { |arg| arg.include?('-') }
      if args.empty?
        nil
      else
        index = [index, args.length - 1].min
        args[index].tr('[].', '')
      end
    end

    private

    # Return +true+ if the given number of arguments is acceptable for the
    # command, +false+ otherwise.
    def num_args_ok?(num_args)
      args = @usage.split.drop(1)
      min_args = args.reject { |arg| arg.start_with?('[') }.length
      if args.empty?
        max_args = 0
      elsif args.any? { |arg| arg.end_with?('...') }
        max_args = num_args
      else
        max_args = args.length
      end
      (min_args..max_args).include?(num_args)
    end
  end

  # Change the remote working directory.
  CD = Command.new(
    'cd [REMOTE_DIR]',
    "Change the remote working directory. With no arguments, changes to the \
     Dropbox root. With a remote directory name as the argument, changes to \
     that directory. With - as the argument, changes to the previous working \
     directory.",
    lambda do |client, state, args, output|
      if args.empty?
        state.pwd = '/'
      elsif args[0] == '-'
        state.pwd = state.oldpwd
      else
        path = state.resolve_path(args[0])
        if state.directory?(path)
          state.pwd = path
        else
          output.call('Not a directory')
        end
      end
    end
  )

  # Copy remote files.
  CP = Command.new(
    'cp REMOTE_FILE... REMOTE_FILE',
    "When given two arguments, copies the remote file or folder at the first \
     path to the second path. When given more than two arguments or when the \
     final argument is a directory, copies each remote file or folder into \
     that directory.",
    lambda do |client, state, args, output|
      cp_mv(client, state, args, output, 'cp', :file_copy)
    end
  )

  # Terminate the session.
  EXIT = Command.new(
    'exit',
    "Exit the program.",
    lambda do |client, state, args, output|
      state.exit_requested = true
    end
  )

  # Clear the cache.
  FORGET = Command.new(
    'forget [REMOTE_DIR]...',
    "Clear the client-side cache of remote filesystem metadata. With no \
     arguments, clear the entire cache. If given directories as arguments, \
     (recursively) clear the cache of those directories only.",
    lambda do |client, state, args, output|
      if args.empty?
        state.cache.clear
      else
        args.each do |arg|
          state.forget_contents(arg) { |line| output.call(line) }
        end
      end
    end
  )

  # Download remote files.
  GET = Command.new(
    'get REMOTE_FILE...',
    "Download each specified remote file to a file of the same name in the \
     local working directory.",
    lambda do |client, state, args, output|
      state.expand_patterns(args).each do |path|
        if path.is_a?(GlobError)
          output.call("get: #{path}: No such file or directory")
        else
          try_and_handle(DropboxError, output) do
            contents = client.get_file(path)
            File.open(File.basename(path), 'wb') do |file|
              file.write(contents)
            end
            output.call("#{File.basename(path)} <- #{path}")
          end
        end
      end
    end
  )

  # List commands, or print information about a specific command.
  HELP = Command.new(
    'help [COMMAND]',
    "Print usage and help information about a command. If no command is \
     given, print a list of commands instead.",
    lambda do |client, state, args, output|
      if args.empty?
        Text.table(NAMES).each { |line| output.call(line) }
      else
        cmd_name = args[0]
        if NAMES.include?(cmd_name)
          cmd = const_get(cmd_name.upcase.to_s)
          output.call(cmd.usage)
          Text.wrap(cmd.description).each { |line| output.call(line) }
        else
          output.call("Unrecognized command: #{cmd_name}")
        end
      end
    end
  )

  # Change the local working directory.
  LCD = Command.new(
    'lcd [LOCAL_DIR]',
    "Change the local working directory. With no arguments, changes to the \
     home directory. With a local directory name as the argument, changes to \
     that directory. With - as the argument, changes to the previous working \
     directory.",
    lambda do |client, state, args, output|
      path = if args.empty?
        File.expand_path('~')
      elsif args[0] == '-'
        state.local_oldpwd
      else
        File.expand_path(args[0])
      end

      if Dir.exists?(path)
        state.local_oldpwd = Dir.pwd
        Dir.chdir(path)
      else
        output.call("lcd: #{args[0]}: No such file or directory")
      end
    end
  )

  # List remote files.
  LS = Command.new(
    'ls [-l] [REMOTE_FILE]...',
    "List information about remote files. With no arguments, list the \
     contents of the working directory. When given remote directories as \
     arguments, list the contents of the directories. When given remote files \
     as arguments, list the files. If the -l option is given, display \
     information about the files.",
    lambda do |client, state, args, output|
      long = args.delete('-l') != nil

      files, dirs = [], []
      state.expand_patterns(args, true).each do |path|
        if path.is_a?(GlobError)
          output.call("ls: #{path}: No such file or directory")
        else
          type = state.directory?(path) ? dirs : files
          type << path
        end
      end

      dirs << state.pwd if args.empty?

      # First list files
      list(state, files, files, long) { |line| output.call(line) }
      output.call('') if !(dirs.empty? || files.empty?)

      # Then list directory contents
      dirs.each_with_index do |dir, i|
        output.call(dir + ':') if dirs.length + files.length > 1
        contents = state.contents(dir)
        names = contents.map { |path| File.basename(path) }
        list(state, contents, names, long) { |line| output.call(line) }
        output.call('') if i < dirs.length - 1
      end
    end
  )

  # Get temporary links to remote files.
  MEDIA = Command.new(
    'media REMOTE_FILE...',
    "Create Dropbox links to publicly share remote files. The links are \
     time-limited and link directly to the files themselves.",
    lambda do |client, state, args, output|
      state.expand_patterns(args).each do |path|
        if path.is_a?(GlobError)
          output.call("media: #{path}: No such file or directory")
        else
          try_and_handle(DropboxError, output) do
            url = client.media(path)['url']
            output.call("#{File.basename(path)} -> #{url}")
          end
        end
      end
    end
  )

  # Create a remote directory.
  MKDIR = Command.new(
    'mkdir REMOTE_DIR...',
    "Create remote directories.",
    lambda do |client, state, args, output|
      args.each do |arg|
        try_and_handle(DropboxError, output) do
          path = state.resolve_path(arg)
          state.cache[path] = client.file_create_folder(path)
        end
      end
    end
  )

  # Move/rename remote files.
  MV = Command.new(
    'mv REMOTE_FILE... REMOTE_FILE',
    "When given two arguments, moves the remote file or folder at the first \
     path to the second path. When given more than two arguments or when the \
     final argument is a directory, moves each remote file or folder into \
     that directory.",
    lambda do |client, state, args, output|
      cp_mv(client, state, args, output, 'mv', :file_move)
    end
  )

  # Upload a local file.
  PUT = Command.new(
    'put LOCAL_FILE [REMOTE_FILE]',
    "Upload a local file to a remote path. If a remote file of the same name \
     already exists, Dropbox will rename the upload. When given only a local \
     file path, the remote path defaults to a file of the same name in the \
     remote working directory.",
    lambda do |client, state, args, output|
      from_path = args[0]
      if args.length == 2
        to_path = args[1]
      else
        to_path = File.basename(from_path)
      end
      to_path = state.resolve_path(to_path)

      try_and_handle(Exception, output) do 
        File.open(File.expand_path(from_path), 'rb') do |file|
          data = client.put_file(to_path, file)
          state.cache[data['path']] = data
          output.call("#{from_path} -> #{data['path']}")
        end
      end
    end
  )

  # Remove remote files.
  RM = Command.new(
    'rm REMOTE_FILE...',
    "Remove each specified remote file or directory.",
    lambda do |client, state, args, output|
      state.expand_patterns(args).each do |path|
        if path.is_a?(GlobError)
          output.call("rm: #{path}: No such file or directory")
        else
          try_and_handle(DropboxError, output) do
            client.file_delete(path)
            state.cache.delete(path)
          end
        end
      end
    end
  )

  # Get permanent links to remote files.
  SHARE = Command.new(
    'share REMOTE_FILE...',
    "Create Dropbox links to publicly share remote files. The links are \
     shortened and direct to 'preview' pages of the files. Links created by \
     this method are set to expire far enough in the future so that \
     expiration is effectively not an issue.",
    lambda do |client, state, args, output|
      state.expand_patterns(args).each do |path|
        if path.is_a?(GlobError)
          output.call("share: #{path}: No such file or directory")
        else
          try_and_handle(DropboxError, output) do
            url = client.shares(path)['url']
            output.call("#{File.basename(path)} -> #{url}")
          end
        end
      end
    end
  )

  # +Array+ of all command names.
  NAMES = constants.select do |sym|
     const_get(sym).is_a?(Command)
  end.map { |sym| sym.to_s.downcase }

  # Parse and execute a line of user input in the given context.
  def self.exec(input, client, state)
    if input.start_with?('!')
      shell(input[1, input.length - 1]) { |line| puts line }
    elsif not input.empty?
      tokens = tokenize(input)
      cmd, args = tokens[0], tokens.drop(1)
      try_command(cmd, args, client, state)
    end
  end

  private

  # Attempt to run the associated block, handling the given type of +Exception+
  # by passing its +String+ representation to an output +Proc+.
  def self.try_and_handle(exception_class, output)
    yield
  rescue exception_class => error
    output.call(error.to_s)
  end

  # Run a command with the given name, or print an error message if usage is
  # incorrect or no such command exists.
  def self.try_command(command_name, args, client, state)
    if NAMES.include?(command_name)
      begin
        command = const_get(command_name.upcase.to_sym)
        command.exec(client, state, *args) { |line| puts line }
      rescue UsageError => error
        puts "Usage: #{error}"
      end
    else
      puts "droxi: #{command_name}: command not found"
    end
  end

  # Split a +String+ into tokens, allowing for backslash-escaped spaces, and
  # return the resulting +Array+.
  def self.tokenize(string)
    string.split.reduce([]) do |list, token|
      list << if !list.empty? && list.last.end_with?('\\')
        "#{list.pop.chop} #{token}"
      else
        token
      end
    end
  end

  # Return a +String+ of information about a remote file for ls -l.
  def self.long_info(state, path, name)
    meta = state.metadata(state.resolve_path(path), false)
    is_dir = meta['is_dir'] ? 'd' : '-'
    size = meta['size'].sub(/ (.)B/, '\1').sub(' bytes', '').rjust(7)
    mtime = Time.parse(meta['modified'])
    format_str = (mtime.year == Time.now.year) ? '%b %e %H:%M' : '%b %e  %Y'
    "#{is_dir} #{size} #{mtime.strftime(format_str)} #{name}"
  end

  # Yield lines of output for the ls command executed on the given file paths
  # and names.
  def self.list(state, paths, names, long)
    if long
      paths.zip(names).each { |path, name| yield long_info(state, path, name) }
    else
      Text.table(names).each { |line| yield line }
    end
  end

  # Run a command in the system shell and yield lines of output.
  def self.shell(cmd)
    IO.popen(cmd) do |pipe|
      pipe.each_line { |line| yield line.chomp if block_given? }
    end
  rescue Interrupt
  rescue Exception => error
    yield error.to_s if block_given?
  end

  # Return an +Array+ of paths from an +Array+ of globs, passing error messages
  # to the output +Proc+ for non-matches.
  def self.expand(state, paths, preserve_root, output, cmd_name)
    state.expand_patterns(paths, true).map do |item|
      if item.is_a?(GlobError)
        output.call("#{cmd_name}: #{item}: no such file or directory")
        nil
      else
        item
      end
    end.compact
  end

  # Copies or moves the file at +source+ to +dest+ and passes a description of
  # the operation to the output +Proc+.
  def self.copy_move(method, source, dest, client, state, output)
    from_path, to_path = [source, dest].map { |p| state.resolve_path(p) }
    try_and_handle(DropboxError, output) do
      metadata = client.send(method, from_path, to_path)
      state.cache.delete(from_path) if method == :file_move
      state.cache_add(metadata)
      output.call("#{source} -> #{dest}")
    end
  end

  # Execute a 'mv' or 'cp' operation depending on arguments given.
  def self.cp_mv(client, state, args, output, cmd, method)
    sources = expand(state, args.take(args.length - 1), true, output, cmd)
    dest = state.resolve_path(args.last)

    if sources.length == 1 && !state.directory?(dest)
      copy_move(method, sources[0], args.last, client, state, output)
    else
      if state.metadata(dest)
        sources.each do |source|
          to_path = args.last.chomp('/') + '/' + File.basename(source)
          copy_move(method, source, to_path, client, state, output)
        end
      else
        output.call("#{cmd}: #{args.last}: no such directory")
      end
    end
  end

end
