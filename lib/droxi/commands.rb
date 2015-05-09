require 'time'

require_relative 'text'

# Module containing definitions for client commands.
module Commands
  # Exception indicating that a client command was given the wrong number of
  # arguments.
  UsageError = Class.new(ArgumentError)

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
    # its behavior. The +Proc+ will receive three arguments: the
    # +DropboxClient+, the +State+, and an +Array+ of command-line arguments.
    def initialize(usage, description, procedure)
      @usage = usage
      @description = description.squeeze(' ')
      @procedure = procedure
    end

    # Attempt to execute the +Command+. Raises a +UsageError+ if an invalid
    # number of command-line arguments is given.
    def exec(client, state, *args)
      fail UsageError, @usage unless num_args_ok?(args.size)
      @procedure.yield(client, state, args)
    end

    # Return a +String+ describing the type of argument at the given index.
    # If the index is out of range, return the type of the final argument. If
    # the +Command+ takes no arguments, return +nil+.
    def type_of_arg(index)
      args = @usage.gsub(/\[-.+?\]/, '').split.drop(1)
      return nil if args.empty?
      index = [index, args.size - 1].min
      args[index].tr('[].', '')
    end

    private

    # Return +true+ if the given number of arguments is acceptable for the
    # command, +false+ otherwise.
    def num_args_ok?(num_args)
      args = @usage.split.drop(1)
      min_args = args.reject { |arg| arg[/[\[\]]/] }.size
      max_args = if args.any? { |arg| arg.end_with?('...') }
                   num_args
                 else
                   args.size
                 end
      (min_args..max_args).include?(num_args)
    end
  end

  # Print the contents of remote files.
  CAT = Command.new(
    'cat REMOTE_FILE...',
    'Print the concatenated contents of remote files.',
    lambda do |client, state, args|
      extract_flags(CAT.usage, args, {})
      state.expand_patterns(args).each do |path|
        if path.is_a?(GlobError)
          warn "cat: #{path}: no such file or directory"
        else
          puts client.get_file(path)
        end
      end
    end
  )

  # Change the remote working directory.
  CD = Command.new(
    'cd [REMOTE_DIR]',
    "Change the remote working directory. With no arguments, changes to the \
     Dropbox root. With a remote directory name as the argument, changes to \
     that directory. With - as the argument, changes to the previous working \
     directory.",
    lambda do |_client, state, args|
      extract_flags(CD.usage, args, {})
      case
      when args.empty? then state.pwd = '/'
      when args.first == '-' then state.pwd = state.oldpwd
      else
        path = state.resolve_path(args.first)
        if state.directory?(path)
          state.pwd = path
        else
          warn "cd: #{args.first}: no such directory"
        end
      end
    end
  )

  # Copy remote files.
  CP = Command.new(
    'cp [-f] REMOTE_FILE... REMOTE_FILE',
    "When given two arguments, copies the remote file or folder at the first \
     path to the second path. When given more than two arguments or when the \
     final argument is a directory, copies each remote file or folder into \
     that directory. Will refuse to overwrite existing files unless invoked \
     with the -f option.",
    lambda do |client, state, args|
      cp_mv(client, state, args, 'cp', CP.usage)
    end
  )

  # Execute arbitrary code.
  DEBUG = Command.new(
    'debug STRING...',
    "Evaluates the given string as Ruby code and prints the result. Won't \
     work unless the program was invoked with the --debug flag.",
    # rubocop:disable Lint/UnusedBlockArgument, Lint/Eval
    lambda do |client, state, args|
      if ARGV.include?('--debug')
        begin
          p eval(args.join(' '))
          # rubocop:enable Lint/UnusedBlockArgument, Lint/Eval
        rescue SyntaxError => error
          warn error
        rescue => error
          warn error.inspect
        end
      else
        warn 'debug: not enabled.'
      end
    end
  )

  # Terminate the session.
  EXIT = Command.new(
    'exit',
    'Exit the program.',
    lambda do |_client, state, args|
      extract_flags(EXIT.usage, args, {})
      state.exit_requested = true
    end
  )

  # Clear the cache.
  FORGET = Command.new(
    'forget [REMOTE_DIR]...',
    "Clear the client-side cache of remote filesystem metadata. With no \
     arguments, clear the entire cache. If given directories as arguments, \
     (recursively) clear the cache of those directories only.",
    lambda do |_client, state, args|
      extract_flags(FORGET.usage, args, {})
      if args.empty?
        state.cache.clear
      else
        args.each do |arg|
          state.forget_contents(arg) { |line| warn line }
        end
      end
    end
  )

  # Download remote files.
  GET = Command.new(
    'get [-f] REMOTE_FILE...',
    "Download each specified remote file to a file of the same name in the \
     local working directory. Will refuse to overwrite existing files unless \
     invoked with the -f option.",
    lambda do |client, state, args|
      flags = extract_flags(GET.usage, args, '-f' => 0)

      state.expand_patterns(args).each do |path|
        if path.is_a?(GlobError)
          warn "get: #{path}: no such file or directory"
        else
          basename = File.basename(path)
          try_and_handle(DropboxError) do
            if flags.include?('-f') || !File.exist?(basename)
              contents = client.get_file(path)
              IO.write(basename, contents, mode: 'wb')
              puts "#{basename} <- #{path}"
            else
              warn "get: #{basename}: local file already exists"
            end
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
    lambda do |_client, _state, args|
      extract_flags(HELP.usage, args, {})
      if args.empty?
        puts 'Type "help <command>" for more info about a command:'
        Text.table(NAMES).each { |line| puts line }
      else
        cmd_name = args.first
        if NAMES.include?(cmd_name)
          cmd = const_get(cmd_name.upcase.to_s)
          puts cmd.usage
          Text.wrap(cmd.description).each { |line| puts line }
        else
          warn "help: #{cmd_name}: no such command"
        end
      end
    end
  )

  # Get remote file revisions.
  HISTORY = Command.new(
    'history REMOTE_FILE',
    "Print a list of revisions for a remote file. The file can be restored to \
     a previous revision using the 'restore' command and a revision ID given \
     by this command.",
    lambda do |client, state, args|
      extract_flags(HISTORY.usage, args, {})
      path = state.resolve_path(args.first)
      if !state.metadata(path) || state.directory?(path)
        warn "history: #{args.first}: no such file"
      else
        try_and_handle(DropboxError) do
          client.revisions(path).each do |rev|

            size = rev['size'].sub(/ (.)B/, '\1').sub(' bytes', '').rjust(7)
            mtime = Time.parse(rev['modified'])
            current_year = (mtime.year == Time.now.year)
            format_str = current_year ? '%b %e %H:%M' : '%b %e  %Y'
            puts "#{size} #{mtime.strftime(format_str)} #{rev['rev']}"
          end
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
    lambda do |_client, state, args|
      extract_flags(LCD.usage, args, {})
      path = case
             when args.empty? then File.expand_path('~')
             when args.first == '-' then state.local_oldpwd
             else
               begin
                 File.expand_path(args.first)
               rescue ArgumentError
                 args.first
               end
             end

      if Dir.exist?(path)
        state.local_oldpwd = Dir.pwd
        Dir.chdir(path)
      else
        warn "lcd: #{args.first}: no such directory"
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
    lambda do |_client, state, args|
      long = extract_flags(LS.usage, args, '-l' => 0).include?('-l')

      files, dirs = [], []
      state.expand_patterns(args, true).each do |path|
        if path.is_a?(GlobError)
          warn "ls: #{path}: no such file or directory"
        else
          type = state.directory?(path) ? dirs : files
          type << path
        end
      end

      dirs << state.pwd if args.empty?

      # First list files.
      list(state, files, files, long) { |line| puts line }
      puts unless dirs.empty? || files.empty?

      # Then list directory contents.
      dirs.each_with_index do |dir, i|
        puts "#{dir}:" if dirs.size + files.size > 1
        contents = state.contents(dir)
        names = contents.map { |path| File.basename(path) }
        list(state, contents, names, long) { |line| puts line }
        puts if i < dirs.size - 1
      end
    end
  )

  # Get temporary links to remote files.
  MEDIA = Command.new(
    'media REMOTE_FILE...',
    "Create Dropbox links to publicly share remote files. The links are \
     time-limited and link directly to the files themselves.",
    lambda do |client, state, args|
      extract_flags(MEDIA.usage, args, {})
      state.expand_patterns(args).each do |path|
        if path.is_a?(GlobError)
          warn "media: #{path}: no such file or directory"
        else
          try_and_handle(DropboxError) do
            url = client.media(path)['url']
            puts "#{File.basename(path)} -> #{url}"
          end
        end
      end
    end
  )

  # Create a remote directory.
  MKDIR = Command.new(
    'mkdir REMOTE_DIR...',
    'Create remote directories.',
    lambda do |client, state, args|
      extract_flags(MKDIR.usage, args, {})
      args.each do |arg|
        try_and_handle(DropboxError) do
          path = state.resolve_path(arg)
          metadata = client.file_create_folder(path)
          state.cache.add(metadata)
        end
      end
    end
  )

  # Move/rename remote files.
  MV = Command.new(
    'mv [-f] REMOTE_FILE... REMOTE_FILE',
    "When given two arguments, moves the remote file or folder at the first \
     path to the second path. When given more than two arguments or when the \
     final argument is a directory, moves each remote file or folder into \
     that directory. Will refuse to overwrite existing files unless invoked \
     with the -f option.",
    lambda do |client, state, args|
      cp_mv(client, state, args, 'mv', MV.usage)
    end
  )

  # Upload a local file.
  PUT = Command.new(
    'put [-f] [-q] [-O REMOTE_DIR] [-t COUNT] LOCAL_FILE...',
    "Upload local files to the remote working directory. If a remote file of \
     the same name already exists, Dropbox will rename the upload unless the \
     the -f option is given, in which case the remote file will be \
     overwritten. If the -O option is given, the files will be uploaded to \
     the given directory instead of the current directory. The -q option \
     prevents progress from being printed. The -t option specifies the \
     number of tries in case of error. The default is 5; -t 0 will retry \
     infinitely.",
    lambda do |client, state, args|
      flags = extract_flags(PUT.usage, args,
                            '-f' => 0,
                            '-q' => 0,
                            '-O' => 1,
                            '-t' => 1)

      dest_index = flags.find_index('-O')
      dest_path = nil
      unless dest_index.nil?
        dest_path = flags[dest_index + 1]
        if state.directory?(dest_path)
          state.pwd = state.resolve_path(dest_path)
        else
          warn "put: #{dest_path}: no such directory"
          return
        end
      end

      tries_index = flags.find_index('-t')
      tries = tries_index ? flags[tries_index + 1].to_i : 5

      # Glob arguments.
      args.map! do |arg|
        array = Dir.glob(File.expand_path(arg))
        warn "put: #{arg}: no such file or directory" if array.empty?
        array.map { |path| path.sub(File.dirname(path), File.dirname(arg)) }
      end
      args = args.reduce(:+)

      args.each do |arg|
        to_path = state.resolve_path(File.basename(arg))

        try_and_handle(StandardError) do
          path = File.expand_path(arg)
          if File.directory?(path)
            warn "put: #{arg}: cannot put directory"
            next
          end

          File.open(path, 'rb') do |file|
            if flags.include?('-f') && state.metadata(to_path)
              client.file_delete(to_path)
              state.cache.remove(to_path)
            end

            # Chunked upload if file is more than 1M.
            if file.size > 1024 * 1024
              data = chunked_upload(client, to_path, file,
                                    flags.include?('-q'), tries)
            else
              data = client.put_file(to_path, file)
            end

            state.cache.add(data)
            puts "#{arg} -> #{data['path']}"
          end
        end
      end

      state.pwd = state.oldpwd unless dest_path.nil?
    end
  )

  # Restore a remove file to a previous version.
  RESTORE = Command.new(
    'restore REMOTE_FILE REVISION_ID',
    "Restore a remote file to a previous version. Use the 'history' command \
     to get a list of IDs for previous revisions of the file.",
    lambda do |client, state, args|
      extract_flags(RESTORE.usage, args, {})
      path = state.resolve_path(args.first)
      if !state.metadata(path) || state.directory?(path)
        warn "restore: #{args.first}: no such file"
      else
        try_and_handle(DropboxError) do
          client.restore(path, args.last)
        end
      end
    end
  )

  # Remove remote files.
  RM = Command.new(
    'rm [-r] REMOTE_FILE...',
    "Remove each specified remote file. If the -r option is given, will \
     also remove directories recursively.",
    lambda do |client, state, args|
      flags = extract_flags(RM.usage, args, '-r' => 0)
      state.expand_patterns(args).each do |path|
        if path.is_a?(GlobError)
          warn "rm: #{path}: no such file or directory"
        else
          if state.directory?(path) && !flags.include?('-r')
            warn "rm: #{path}: is a directory"
            next
          end
          try_and_handle(DropboxError) do
            client.file_delete(path)
            state.cache.remove(path)
          end
        end
      end
      check_pwd(state)
    end
  )

  # Remove remote directories.
  RMDIR = Command.new(
    'rmdir REMOTE_DIR...',
    'Remove each specified empty remote directory.',
    lambda do |client, state, args|
      extract_flags(RMDIR.usage, args, {})
      state.expand_patterns(args).each do |path|
        if path.is_a?(GlobError)
          warn "rmdir: #{path}: no such file or directory"
        else
          unless state.directory?(path)
            warn "rmdir: #{path}: not a directory"
            next
          end
          contents = state.metadata(path)['contents']
          if contents && !contents.empty?
            warn "rmdir: #{path}: directory not empty"
            next
          end
          try_and_handle(DropboxError) do
            client.file_delete(path)
            state.cache.remove(path)
          end
        end
      end
      check_pwd(state)
    end
  )

  # Search for remote files.
  SEARCH = Command.new(
    'search REMOTE_DIR SUBSTRING...',
    "List remote files in a directory or its subdirectories with names that \
     contain all given substrings.",
    lambda do |client, state, args|
      extract_flags(SEARCH.usage, args, {})
      path = state.resolve_path(args.first)
      unless state.directory?(path)
        warn "search: #{args.first}: no such directory"
        return
      end
      query = args.drop(1).join(' ')
      try_and_handle(DropboxError) do
        client.search(path, query).each { |result| puts result['path'] }
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
    lambda do |client, state, args|
      extract_flags(SHARE.usage, args, {})
      state.expand_patterns(args).each do |path|
        if path.is_a?(GlobError)
          warn "share: #{path}: no such file or directory"
        else
          try_and_handle(DropboxError) do
            url = client.shares(path)['url']
            puts "#{File.basename(path)} -> #{url}"
          end
        end
      end
    end
  )

  # Return an +Array+ of all command names.
  def self.names
    symbols = constants.select { |sym| const_get(sym).is_a?(Command) }
    symbols.map { |sym| sym.to_s.downcase }
  end

  # +Array+ of all command names.
  NAMES = names

  # Parse and execute a line of user input in the given context.
  def self.exec(input, client, state)
    if input.start_with?('!')
      shell(input[1, input.size - 1]) { |line| puts line }
    elsif !input.empty?
      tokens = Text.tokenize(input)
      cmd, args = tokens.first, tokens.drop(1)
      try_command(cmd, args, client, state)
    end
  end

  private

  # Attempt to run the associated block, handling the given type of +Exception+
  # by issuing a warning using its +String+ representation.
  def self.try_and_handle(exception_class)
    yield
  rescue exception_class => error
    warn error
  end

  # Run a command with the given name, or print an error message if usage is
  # incorrect or no such command exists.
  def self.try_command(command_name, args, client, state)
    if NAMES.include?(command_name)
      begin
        command = const_get(command_name.upcase.to_sym)
        command.exec(client, state, *args) { |line| puts line }
      rescue UsageError => error
        warn "Usage: #{error}"
      end
    else
      warn "droxi: #{command_name}: command not found"
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
    yield ''
  rescue Errno::ENOENT => error
    yield error.to_s if block_given?
  end

  # Return an +Array+ of paths from an +Array+ of globs, printing error
  # messages if +output+ is true.
  def self.expand(state, paths, preserve_root, output, cmd)
    state.expand_patterns(paths, preserve_root).map do |item|
      if item.is_a?(GlobError)
        warn "#{cmd}: #{item}: no such file or directory" if output
        nil
      else
        item
      end
    end.compact
  end

  def self.overwrite(path, client, state)
    return unless state.metadata(path)
    client.file_delete(path)
    state.cache.remove(path)
  end

  # Copies or moves a file.
  def self.copy_move(method, args, flags, client, state)
    from_path, to_path = args.map { |p| state.resolve_path(p) }
    try_and_handle(DropboxError) do
      overwrite(to_path, client, state) if flags.include?('-f')
      metadata = client.send(method, from_path, to_path)
      state.cache.remove(from_path) if method == :file_move
      state.cache.add(metadata)
      puts "#{args.first} -> #{args[1]}"
    end
  end

  # Execute a 'mv' or 'cp' operation depending on arguments given.
  def self.cp_mv(client, state, args, cmd, usage)
    flags = extract_flags(usage, args, '-f' => 0)
    sources = expand(state, args.take(args.size - 1), true, true, cmd)
    method = (cmd == 'cp') ? :file_copy : :file_move
    dest = state.resolve_path(args.last)

    if sources.size == 1 && !state.directory?(dest)
      copy_move(method, [sources.first, args.last], flags, client, state)
    else
      cp_mv_to_dir(args, flags, client, state, cmd)
    end
  end

  # Copies or moves files into a directory.
  def self.cp_mv_to_dir(args, flags, client, state, cmd)
    sources = expand(state, args.take(args.size - 1), true, false, cmd)
    method = (cmd == 'cp') ? :file_copy : :file_move
    if state.metadata(state.resolve_path(args.last))
      sources.each do |source|
        to_path = args.last.chomp('/') + '/' + File.basename(source)
        copy_move(method, [source, to_path], flags, client, state)
      end
    else
      warn "#{cmd}: #{args.last}: no such directory"
    end
  end

  # If the remote working directory does not exist, move up the directory
  # tree until at a real location.
  def self.check_pwd(state)
    (state.pwd = File.dirname(state.pwd)) until state.metadata(state.pwd)
  end

  # Removes flags (e.g. -f) from the +Array+ and returns an +Array+ of the
  # removed flags. Prints warnings if the flags are not in the given +String+
  # of valid flags (e.g. '-rf').
  def self.extract_flags(usage, args, flags)
    extracted, index = [], 0
    while index < args.size
      arg = args[index]
      extracted_flags =
        arg[/^-\w/] ? extract_flag(usage, args, flags, arg, index) : nil
      extracted += extracted_flags unless extracted_flags.nil?
      index += 1 if extracted_flags.nil? || extracted_flags.empty?
    end
    args.delete_if { |a| a[/^-\w/] }
    extracted
  end

  # Removes a flag and its arugments from the +Array+ and returns an +Array+ of
  # the flag and its arguments. Prints warnings if the given flag is invalid.
  def self.extract_flag(usage, args, flags, arg, index)
    num_args = flags[arg]
    if num_args.nil?
      fail UsageError, usage
    else
      if index + num_args < args.size
        return (num_args + 1).times.map { args.delete_at(index) }
      end
      fail UsageError, usage
    end
  end

  # Attempts to upload a file to the server in chunks, displaying progress.
  def self.chunked_upload(client, to_path, file, quiet, tries)
    uploader = DropboxClient::ChunkedUploader.new(client, file, file.size)
    thread = quiet ? nil : Thread.new { monitor_upload(uploader, to_path) }
    tries = -1 if tries == 0
    loop_upload(uploader, thread, tries)
    data = uploader.finish(to_path)
    if thread
      thread.join
      print "\r" + (' ' * (18 + to_path.rpartition('/')[2].size)) + "\r"
    end
    data
  end

  # Continuously try to upload until successful or interrupted.
  # rubocop:disable Style/MethodLength
  def self.loop_upload(uploader, monitor_thread, tries)
    while tries != 0 && uploader.offset < uploader.total_size
      begin
        uploader.upload(1024 * 1024)
      rescue DropboxError => error
        puts "\n" + error.to_s
        --tries
      end
    end
  rescue Interrupt => error
    monitor_thread.kill if monitor_thread
    raise error
  end
  # rubocop:enable Style/MethodLength

  # Displays real-time progress for the a being uploaded.
  def self.monitor_upload(uploader, to_path)
    filename = to_path.rpartition('/')[2]
    loop do
      percent = 100.0 * uploader.offset / uploader.total_size
      printf("\rUploading %s: %.1f%%", filename, percent)
      break if uploader.offset == uploader.total_size
      sleep 1
    end
  end
end
