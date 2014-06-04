require 'dropbox_sdk'
require 'readline'

require_relative 'droxi/commands'
require_relative 'droxi/complete'
require_relative 'droxi/settings'
require_relative 'droxi/state'

# Command-line Dropbox client module.
module Droxi

  # Run the client.
  def self.run(*args)
    client = DropboxClient.new(get_access_token)
    state = State.new(client)

    if args.empty?
      run_interactive(client, state)
    else
      with_interrupt_handling do
        cmd = args.map { |arg| arg.gsub(' ', '\ ') }.join(' ')
        Commands.exec(cmd, client, state)
      end
    end

    Settings.save
  end

  private

  # Attempt to authorize the user for app usage. Return +true+ if
  # authorization was successful, +false+ otherwise.
  def self.authorize
    app_key = '5sufyfrvtro9zp7'
    app_secret = 'h99ihzv86jyypho'

    flow = DropboxOAuth2FlowNoRedirect.new(app_key, app_secret)

    authorize_url = flow.start()
    code = get_auth_code(authorize_url)

    begin
      Settings[:access_token] = flow.finish(code)[0]
    rescue DropboxError
      puts 'Invalid authorization code.'
    end
  end

  # Get the access token for the user, requesting authorization if no token
  # exists.
  def self.get_access_token
    authorize() until Settings.include?(:access_token)
    Settings[:access_token]
  end

  # Return a prompt message reflecting the current state of the application.
  def self.prompt(info, state)
    "droxi #{info['email']}:#{state.pwd}> "
  end

  # Run the client in interactive mode.
  def self.run_interactive(client, state)
    info = client.account_info
    puts "Logged in as #{info['display_name']} (#{info['email']})"

    init_readline(state)
    with_interrupt_handling { do_interaction_loop(client, state, info) }

    # Set pwd so that the oldpwd setting is saved to pwd
    state.pwd = '/'
  end

  def self.init_readline(state)
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
      when 'LOCAL_FILE'  then Complete.local(word)
      when 'LOCAL_DIR'   then Complete.local_dir(word)
      when 'REMOTE_FILE' then Complete.remote(word, state)
      when 'REMOTE_DIR'  then Complete.remote_dir(word, state)
      else []
      end

      options.map { |option| option.gsub(' ', '\ ').sub(/\\ $/, ' ') }
    end

    begin
      Readline.completion_append_character = nil
    rescue NotImplementedError
    end
  end

  def self.with_interrupt_handling
    yield
  rescue Interrupt
    puts
  end

  def self.do_interaction_loop(client, state, info)
    while !state.exit_requested &&
          line = Readline.readline(prompt(info, state), true)
      with_interrupt_handling { Commands.exec(line.chomp, client, state) }
    end
    puts if !line
  end

  def self.get_auth_code(url)
    puts '1. Go to: ' + url
    puts '2. Click "Allow" (you might have to log in first)'
    puts '3. Copy the authorization code'
    print '4. Enter the authorization code here: '
    code = $stdin.gets
    code ? code.strip! : exit
  end

end
