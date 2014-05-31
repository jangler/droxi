class UsageError < ArgumentError
end

class Commands
  def Commands.cd(client, state, args)
    case args.length
    when 0 then state.pwd = '/'
    when 1
      if args[0] == '-'
        state.pwd = state.oldpwd
      else
        path = state.resolve_path(args[0])
        begin
          if state.is_dir?(client, path)
            state.pwd = path
          else
            yield 'Not a directory' if block_given?
          end
        rescue DropboxError => error
          yield 'No such file or directory' if block_given?
        end
      end
    else raise UsageError.new('[DIRECTORY]')
    end
  end

  def Commands.get(client, state, args)
    if args.empty?
      raise UsageError.new('FILE...')
    end

    args.each do |arg|
      path = state.resolve_path(arg)

      begin
        contents = client.get_file(path)
        File.open(File.basename(path), 'wb') do |file|
          file.write(contents)
        end
      rescue DropboxError => error
        yield error.to_s if block_given?
      end
    end
  end

  def Commands.ls(client, state, args)
    if block_given?
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

      patterns.each do |pattern|
        begin
          matches = []
          dir = File.dirname(pattern)
          state.contents(client, dir).each do |path|
            matches << File.basename(path) if File.fnmatch(pattern, path)
          end
          matches.each { |match| yield match }
        rescue DropboxError => error
          yield error.to_s
        end
      end
    end
  end

  def Commands.mkdir(client, state, args)
    if args.empty?
      raise UsageError.new('DIRECTORY...')
    else
      args.each do |arg|
        begin
          path = state.resolve_path(arg)
          state.cache[path] = client.file_create_folder(path)
        rescue DropboxError => error
          yield error.to_s if block_given?
        end
      end
    end
  end

  def Commands.put(client, state, args)
    case args.length
    when 1 then from_path = to_path = args[0]
    when 2 then from_path, to_path = args[0], args[1]
    else
      raise UsageError.new('FILE [DESTINATION]')
    end

    to_path = state.resolve_path(to_path)

    begin
      File.open(File.expand_path(from_path), 'rb') do |file|
        state.cache[to_path] = client.put_file(to_path, file)
      end
    rescue Exception => error
      yield error.to_s if block_given?
    end
  end

  def Commands.rm(client, state, args)
    if args.empty?
      raise UsageError.new('FILE...')
    else
      state.expand_patterns(client, args).each do |path|
        begin
          client.file_delete(path)
          state.cache.delete(path)
        rescue DropboxError => error
          yield error.to_s if block_given?
        end
      end
    end
  end

  def Commands.share(client, state, args)
    if args.empty?
      raise UsageError.new('FILE...')
    elsif block_given?
      state.expand_patterns(client, args).each do |path|
        begin
          yield "#{path}: #{client.shares(path)['url']}"
        rescue DropboxError => error
          yield error.to_s
        end
      end
    end
  end

  def Commands.shell(cmd)
    begin
      IO.popen(cmd) do |pipe|
        pipe.each_line { |line| yield line.chomp if block_given? }
      end
    rescue Interrupt
    rescue Exception => error
      yield error.to_s if block_given?
    end
  end

  def Commands.exec(input, client, state)
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

      cmd, args = tokens[0].to_sym, tokens.drop(1)

      methods = singleton_methods.reject do |method| 
        [:exec, :shell].include?(method)
      end

      if methods.include?(cmd)
        begin
          send(cmd, client, state, args) { |line| puts line }
        rescue UsageError => error
          puts "Usage: #{cmd} #{error}"
        end
      else
        puts "Unrecognized command: #{cmd}"
      end
    end
  end
end
