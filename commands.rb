require 'readline'

module Commands
  class UsageError < ArgumentError
  end

  class Command
    attr_reader :usage, :description

    def initialize(usage, description, procedure)
      @usage = usage
      @description = description.squeeze(' ')
      @procedure = procedure
    end

    def exec(client, state, *args)
      if num_args_ok?(args.length)
        block = proc { |line| yield line if block_given? }
        @procedure.yield(client, state, args, block)
      else
        raise UsageError.new(@usage)
      end
    end

    def num_args_ok?(num_args)
      args = @usage.split.drop(1)
      min_args = args.reject { |arg| arg.start_with?('[') }.length
      if args.last.end_with?('...')
        max_args = num_args
      else
        max_args = args.length
      end
      (min_args..max_args).include?(num_args)
    end

    def type_of_arg(index)
      args = @usage.split.drop(1)
      index = [index, args.length - 1].min
      args[index].tr('[].', '')
    end
  end

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
        if state.is_dir?(client, path)
          state.pwd = path
        else
          output.call('Not a directory')
        end
      end
    end
  )

  GET = Command.new(
    'get REMOTE_FILE...',
    "Download each specified remote file to a file of the same name in the \
     local working directory.",
    lambda do |client, state, args, output|
      state.expand_patterns(client, args).each do |path|
        begin
          contents = client.get_file(path)
          File.open(File.basename(path), 'wb') do |file|
            file.write(contents)
          end
        rescue DropboxError => error
          output.call(error.to_s)
        end
      end
    end
  )

  HELP = Command.new(
    'help [COMMAND]',
    "Print usage and help information about a command. If no command is \
     given, print a list of commands instead.",
    lambda do |client, state, args, output|
      if args.empty?
        table_output(NAMES).each { |line| output.call(line) }
      else
        cmd_name = args[0]
        if NAMES.include?(cmd_name)
          cmd = const_get(cmd_name.upcase.to_s)
          output.call(cmd.usage)
          wrap_output(cmd.description).each { |line| output.call(line) }
        else
          output.call("Unrecognized command: #{cmd_name}")
        end
      end
    end
  )

  LS = Command.new(
    'ls [REMOTE_FILE]...',
    "List information about remote files. With no arguments, list the \
     contents of the working directory. When given remote directories as \
     arguments, list the contents of the directories. When given remote files \
     as arguments, list the files.",
    lambda do |client, state, args, output|
      patterns = if args.empty?
        ["#{state.pwd}/*".sub('//', '/')]
      else
        args.map do |path|
          path = state.resolve_path(path)
          begin
            if state.is_dir?(client, path)
              "#{path}/*".sub('//', '/')
            else
              path
            end
          rescue DropboxError
            path
          end
        end
      end

      items = []
      patterns.each do |pattern|
        begin
          dir = File.dirname(pattern)
          state.contents(client, dir).each do |path|
            items << File.basename(path) if File.fnmatch(pattern, path)
          end
        rescue DropboxError => error
          output.call(error.to_s)
        end
      end
      table_output(items).each { |item| output.call(item) }
    end
  )

  MKDIR = Command.new(
    'mkdir REMOTE_DIR...',
    "Create remote directories.",
    lambda do |client, state, args, output|
      args.each do |arg|
        begin
          path = state.resolve_path(arg)
          state.cache[path] = client.file_create_folder(path)
        rescue DropboxError => error
          output.call(error.to_s)
        end
      end
    end
  )

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
        to_path = from_path
      end
      to_path = state.resolve_path(to_path)

      begin
        File.open(File.expand_path(from_path), 'rb') do |file|
          state.cache[to_path] = client.put_file(to_path, file)
        end
      rescue Exception => error
        output.call(error.to_s)
      end
    end
  )

  RM = Command.new(
    'rm REMOTE_FILE...',
    "Remove each specified remote file or directory.",
    lambda do |client, state, args, output|
      state.expand_patterns(client, args).each do |path|
        begin
          client.file_delete(path)
          state.cache.delete(path)
        rescue DropboxError => error
          output.call(error.to_s)
        end
      end
    end
  )

  SHARE = Command.new(
    'share REMOTE_FILE...',
    "Get URLs to share remote files. Shareable links created on Dropbox are \
     time-limited, but don't require any authentication, so they can be given \
     out freely. The time limit should allow at least a day of shareability.",
    lambda do |client, state, args, output|
      state.expand_patterns(client, args).each do |path|
        begin
          output.call("#{path}: #{client.shares(path)['url']}")
        rescue DropboxError => error
          output.call(error.to_s)
        end
      end
    end
  )

  NAMES = constants.select do |sym|
     const_get(sym).is_a?(Command)
  end.map { |sym| sym.to_s.downcase }

  def self.exec(input, client, state)
    if input.start_with?('!')
      shell(input[1, input.length - 1]) { |line| puts line }
    elsif not input.empty?
      tokens = input.split

      # Escape spaces with backslash
      i = 0
      while i < tokens.length - 1
        if tokens[i].end_with?('\\')
          tokens[i] = "#{tokens[i].chop} #{tokens.delete_at(i + 1)}"
        else
          i += 1
        end
      end

      cmd, args = tokens[0], tokens.drop(1)

      if NAMES.include?(cmd)
        begin
          const_get(cmd.upcase.to_sym).exec(client, state, *args) do |line|
            puts line
          end
        rescue UsageError => error
          puts "Usage: #{error}"
        end
      else
        puts "Unrecognized command: #{cmd}"
      end
    end
  end

  private

  def self.get_screen_size
    begin
      Readline.get_screen_size[1]
    rescue NotImplementedError
      72
    end
  end

  def self.shell(cmd)
    begin
      IO.popen(cmd) do |pipe|
        pipe.each_line { |line| yield line.chomp if block_given? }
      end
    rescue Interrupt
    rescue Exception => error
      yield error.to_s if block_given?
    end
  end

  def self.table_output(items)
    return [] if items.empty?
    columns = get_screen_size
    item_width = items.map { |item| item.length }.max + 2
    column = 0
    lines = ['']
    items.each do |item|
      if column != 0 && column + item_width >= columns
        lines << ''
        column = 0
      end
      lines.last << item.ljust(item_width)
      column += item_width
    end
    lines
  end

  def self.wrap_output(text)
    columns = get_screen_size
    column = 0
    lines = ['']
    text.split.each do |word|
      if column != 0 && column + word.length >= columns
        lines << ''
        column = 0
      end
      if column != 0
        lines.last << ' '
        column += 1
      end
      lines.last << word
      column += word.length
    end
    lines
  end
end
