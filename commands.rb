require 'pathname'

class Commands
  def Commands.cd(path, client, state)
    path = resolve_path(path, state)
    begin
      if client.metadata(path)['is_dir']
        state.working_dir = path
      else
        puts 'Not a directory'
      end
    rescue DropboxError => error
      puts 'No such file or directory'
    end
  end

  def Commands.get(path, client, state)
    path = resolve_path(path, state)
    begin
      contents = client.get_file(path)
      File.open(Pathname.new(path).basename.to_s, 'wb') do |file|
        file.write(contents)
      end
    rescue DropboxError => error
      puts error
    end
  end

  def Commands.ls(client, state)
    client.metadata(state.working_dir)['contents'].each do |data|
      puts Pathname.new(data['path']).basename
    end
  end

  def Commands.put(path, client, state)
    to_path = resolve_path(File.basename(path), state)
    begin
      File.open(File.expand_path(path), 'rb') do |file|
        client.put_file(to_path, file)
      end
    rescue Exception => error
      puts error
    end
  end

  def Commands.exec(input, client, state)
    tokens = input.split

    case tokens[0]
    when 'cd' then cd(tokens[1], client, state)
    when 'get' then get(tokens[1], client, state)
    when 'ls' then ls(client, state)
    when 'put' then put(tokens[1], client, state)
    else puts "Unrecognized command: #{tokens[0]}"
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
