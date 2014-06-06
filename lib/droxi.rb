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
    client = DropboxClient.new(access_token)
    state = State.new(client)

    if args.empty?
      run_interactive(client, state)
    else
      with_interrupt_handling do
        Commands.exec(join_cmd(args), client, state)
      end
    end

    Settings.save
  end

  private

  # Return a +String+ of joined command-line args, adding backslash escapes for
  # spaces.
  def self.join_cmd(args)
    args.map { |arg| arg.gsub(' ', '\ ') }.join(' ')
  end

  # Attempt to authorize the user for app usage.
  def self.authorize
    app_key = '5sufyfrvtro9zp7'
    app_secret = 'h99ihzv86jyypho' # Not so secret, is it?

    flow = DropboxOAuth2FlowNoRedirect.new(app_key, app_secret)

    authorize_url = flow.start
    code = get_auth_code(authorize_url)

    begin
      Settings[:access_token] = flow.finish(code).first
    rescue DropboxError
      puts 'Invalid authorization code.'
    end
  end

  # Return the access token for the user, requesting authorization if no saved
  # token exists.
  def self.access_token
    authorize until Settings.include?(:access_token)
    Settings[:access_token]
  end

  # Return a prompt message reflecting the current state of the application.
  def self.prompt(info, state)
    "\rdroxi #{info['email']}:#{state.pwd}> "
  end

  # Run the client in interactive mode.
  def self.run_interactive(client, state)
    info = client.account_info
    puts "Logged in as #{info['display_name']} (#{info['email']})"

    init_readline(state)
    with_interrupt_handling { do_interaction_loop(client, state, info) }

    # Set pwd before exiting so that the oldpwd setting is saved to the pwd.
    state.pwd = '/'
  end

  def self.init_readline(state)
    Readline.completion_proc = proc do
      Complete.complete(Readline.line_buffer, state)
    end

    ignore_not_yet_implemented { Readline.completion_append_character = nil }
  end

  def self.ignore_not_yet_implemented
    yield
  rescue NotImplementedError
    nil
  end

  def self.with_interrupt_handling
    yield
  rescue Interrupt
    puts
  end

  # Run the main loop of the program, getting user input and executing it as a
  # command until an getting input fails or an exit is requested.
  def self.do_interaction_loop(client, state, info)
    until state.exit_requested
      line = Readline.readline(prompt(info, state), true)
      break unless line
      with_interrupt_handling { Commands.exec(line.chomp, client, state) }
    end
    puts unless line
  end

  def self.get_auth_code(url)
    puts 'Authorize this app to access your Dropbox at: ' + url
    print 'Enter authorization code: '
    code = $stdin.gets
    code ? code.strip! : exit
  end
end
