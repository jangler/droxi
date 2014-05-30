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
          if client.metadata(path)['is_dir']
            state.pwd = path
          else
            yield 'Not a directory'
          end
        rescue DropboxError => error
          yield 'No such file or directory'
        end
      end
    else raise UsageError.new('[DIRECTORY]')
    end
  end

  def Commands.get(client, state, args)
    case args.length
    when 1 then from_path = to_path = args[0]
    when 2 then from_path, to_path = args
    else
      raise UsageError.new('FILE [DESTINATION]')
    end

    path = state.resolve_path(from_path)

    begin
      contents = client.get_file(path)
      File.open(File.basename(to_path), 'wb') do |file|
        file.write(contents)
      end
    rescue DropboxError => error
      yield error
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
            if client.metadata(path)['is_dir']
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
          client.metadata(File.dirname(pattern))['contents'].each do |data|
            path = data['path']
            matches << File.basename(path) if File.fnmatch(pattern, path)
          end

          if matches.empty?
            yield "ls: cannot access #{pattern}: No such file or directory"
          else
            matches.each { |match| yield match }
          end
        rescue DropboxError => error
          yield error.to_s
        end
      end
    end
  end

  def Commands.mkdir(client, state, args)
    if args.length == 1
      path = state.resolve_path(args[0])
      begin
        client.file_create_folder(path)
      rescue DropboxError => error
        yield error
      end
    else
      raise UsageError.new('DIRECTORY')
    end
  end

  def Commands.put(client, state, args)
    case args.length
    when 1 then from_path = to_path = args[0]
    when 2 then from_path, to_path = args[0], args[1]
    else
      raise UsageError.new('FILE [DESTINATION]')
    end

    to_path = state.resolve_path(File.basename(to_path))

    begin
      File.open(File.expand_path(from_path), 'rb') do |file|
        client.put_file(to_path, file)
      end
    rescue Exception => error
      yield error
    end
  end

  def Commands.rm(client, state, args)
    if args.length == 1
      path = state.resolve_path(args[0])
      begin
        client.file_delete(path)
      rescue DropboxError => error
        yield error
      end
    else
      raise UsageError.new('FILE')
    end
  end

  def Commands.share(client, state, args)
    if args.length == 1
      path = state.resolve_path(args[0])
      begin
        yield client.shares(path)['url']
      rescue DropboxError => error
        yield error
      end
    else
      raise UsageError.new('FILE')
    end
  end

  def Commands.shell(cmd)
    begin
      IO.popen(cmd) do |pipe|
        pipe.each_line { |line| yield line.chomp }
      end
    rescue Interrupt
    rescue Exception => error
      yield error
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
