require 'dropbox_sdk'
require 'readline'

require_relative 'droxi/commands'
require_relative 'droxi/settings'
require_relative 'droxi/state'

# Command-line Dropbox client module.
module Droxi

  # Attempt to authorize the user for app usage.
  def self.authorize
    app_key = '5sufyfrvtro9zp7'
    app_secret = 'h99ihzv86jyypho'

    flow = DropboxOAuth2FlowNoRedirect.new(app_key, app_secret)

    authorize_url = flow.start()

    # Have the user sign in and authorize this app
    puts '1. Go to: ' + authorize_url
    puts '2. Click "Allow" (you might have to log in first)'
    puts '3. Copy the authorization code'
    print 'Enter the authorization code here: '
    code = $stdin.gets
    if code
      code.strip!
    else
      puts
      exit
    end

    # This will fail if the user gave us an invalid authorization code
    begin
      access_token, user_id = flow.finish(code)
      Settings[:access_token] = access_token
    rescue DropboxError
      puts 'Invalid authorization code.'
    end

    nil
  end

  # Get the access token for the user, requesting authorization if no token
  # exists.
  def self.get_access_token
    until Settings.include?(:access_token)
      authorize()
    end
    Settings[:access_token]
  end

  # Print a prompt message reflecting the current state of the application.
  def self.prompt(info, state)
    "droxi #{info['email']}:#{state.pwd}> "
  end

  # Return an +Array+ of potential tab-completions for a partial local file
  # path.
  def self.complete_file(word, dir_only=false)
    begin
      path = File.expand_path(word)
    rescue ArgumentError
      return []
    end
    if word.empty? || (word.length > 1 && word.end_with?('/'))
      dir = path
    else
      dir = File.dirname(path)
    end

    entries = begin
      Dir.entries(dir).reject { |entry| entry.end_with?('.') }
    rescue
      []
    end

    entries.map do |file|
      (dir + '/').sub('//', '/') + file
    end.select do |file|
      file.start_with?(path) && !(dir_only && !File.directory?(file))
    end.map do |file|
      if File.directory?(file)
        file << '/'
      else
        file << ' '
      end
      if word.start_with?('/')
        file
      elsif word.start_with?('~')
        file.sub(/\/home\/[^\/]+/, '~')
      else
        file.sub(Dir.pwd + '/', '')
      end
    end
  end

  # Return an +Array+ of potential tab-completions for a partial local
  # directory path.
  def self.complete_dir(word)
    complete_file(word, true)
  end

  # Run the client.
  def self.run
    client = DropboxClient.new(get_access_token)
    info = client.account_info
    puts "Logged in as #{info['display_name']} (#{info['email']})"

    state = State.new(client)

    Readline.completion_proc = proc do |word|
      words = Readline.line_buffer.split
      index = words.length
      index += 1 if Readline.line_buffer.end_with?(' ')
      if index <= 1
        type = 'COMMAND'
      elsif Commands::NAMES.include?(words[0])
        cmd = Commands.const_get(words[0].upcase.to_sym)
        type = cmd.type_of_arg(index - 2)
      end

      options = case type
      when 'COMMAND'
        Commands::NAMES.select { |name| name.start_with? word }.map do |name|
          name + ' '
        end
      when 'LOCAL_FILE'  then complete_file(word)
      when 'LOCAL_DIR'   then complete_dir(word)
      when 'REMOTE_FILE' then state.complete_file(word)
      when 'REMOTE_DIR'  then state.complete_dir(word)
      else []
      end

      options.map { |option| option.gsub(' ', '\ ').sub(/\\ $/, ' ') }
    end

    begin
      Readline.completion_append_character = nil
    rescue NotImplementedError
    end

    begin
      while !state.exit_requested &&
            line = Readline.readline(prompt(info, state), true)
        Commands.exec(line.chomp, client, state)
      end
      puts if !line
    rescue Interrupt
      puts
    end

    # Set pwd so that the oldpwd setting is set to pwd
    state.pwd = '/'
    Settings.save
  end
end
