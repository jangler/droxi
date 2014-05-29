class Commands
  def Commands.cd(client, state, args)
    case args.length
    when 0 then state.working_dir = '/'
    when 1
      path = resolve_path(args[0], state)
      begin
        if client.metadata(path)['is_dir']
          state.working_dir = path
        else
          yield 'Not a directory'
        end
      rescue DropboxError => error
        yield 'No such file or directory'
      end
    else yield 'Usage: cd [DIRECTORY]'
    end
  end

  def Commands.get(client, state, args)
    case args.length
    when 1 then from_path = to_path = args[0]
    when 2 then from_path, to_path = args
    else
      yield 'Usage: get FILE [DESTINATION]'
      return
    end

    path = resolve_path(from_path, state)
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
    if args.empty?
      client.metadata(state.working_dir)['contents'].each do |data|
        yield File.basename(data['path'])
      end
    else
      yield 'Usage: ls'
    end
  end

  def Commands.mkdir(client, state, args)
    if args.length == 1
      path = resolve_path(args[0], state)
      begin
        client.file_create_folder(path)
      rescue DropboxError => error
        yield error
      end
    else
      yield 'Usage: mkdir DIRECTORY'
    end
  end

  def Commands.put(client, state, args)
    case args.length
    when 1 then from_path = to_path = args[0]
    when 2 then from_path, to_path = args[0], args[1]
    else
      yield "Usage: put FILE [DESTINATION]"
      return
    end

    to_path = resolve_path(File.basename(to_path), state)

    begin
      File.open(File.expand_path(from_path), 'rb') do |file|
        client.put_file(to_path, file)
      end
    rescue Exception => error
      yield error
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
      cmd, args = tokens[0].to_sym, tokens.drop(1)

      methods = singleton_methods.reject do |method| 
        [:exec, :resolve_path].include?(method)
      end

      if methods.include?(cmd)
        send(cmd, client, state, args) { |line| puts line }
      else
        puts "Unrecognized command: #{cmd}"
      end
    end
  end

  private

  def Commands.resolve_path(path, state)
    path = "#{state.working_dir}/#{path}" unless path.start_with?('/')
    path.gsub!('//', '/')
    while path.sub!(/\/([^\/]+?)\/\.\./, '')
    end
    path.chomp!('/')
    path = '/' if path.empty?
    path
  end
end
