require 'pathname'

class Commands
  def Commands.cd(path, client, state)
    begin
      path = "#{state.working_dir}/#{path}" unless path.start_with?('/')
      path.gsub!('//', '/')
      while path.sub!(/\/([^\/]+?)\/\.\./, '')
      end
      path.chomp!('/')
      path = '/' if path.empty?
      if client.metadata(path)['is_dir']
        state.working_dir = path
      else
        puts 'Not a directory'
      end
    rescue DropboxError => error
      puts 'No such file or directory'
    end
  end

  def Commands.ls(client, state)
    client.metadata(state.working_dir)['contents'].each do |data|
      puts Pathname.new(data['path']).basename
    end
  end

  def Commands.exec(input, client, state)
    tokens = input.split

    case tokens[0]
    when 'cd' then cd(tokens[1], client, state)
    when 'ls' then ls(client, state)
    else puts "Unrecognized command: #{tokens[0]}"
    end
  end
end
