begin
  require 'dropbox_sdk'
rescue LoadError
  puts 'droxi requires the dropbox-sdk gem.'
  puts 'Run `gem install dropbox-sdk` to install it.'
  exit
end
require 'optparse'
require 'readline'

require_relative 'droxi/commands'
require_relative 'droxi/complete'
require_relative 'droxi/settings'
require_relative 'droxi/state'
require_relative 'droxi/text'

# Command-line Dropbox client module.
module Droxi
  # Version number of the program.
  VERSION = '0.4.0'

  # Message to display when invoked with the --help option.
  HELP_TEXT = [
    'If invoked without arguments, run in interactive mode. If invoked with ' \
    'arguments, parse the arguments as a command invocation, execute the ' \
    'command, and exit.',
    "For a list of commands, run `droxi help` or use the 'help' command in " \
    'interactive mode.'
  ]

  # Run the client.
  def self.run
    reenter = ARGV[0] == 'REENTER'
    ARGV.delete_if { |arg| arg == 'REENTER' }
    original_argv = ARGV.dup
    options = handle_options
    Settings.init

    client = DropboxClient.new(access_token)
    state = State.new(client, ARGV.empty?, original_argv)
    state.debug_enabled = options[:debug]

    if ARGV.empty?
      run_interactive(client, state, reenter)
    else
      invoke(ARGV, client, state)
    end
  rescue DropboxAuthError => error
    warn error
    Settings.delete(:access_token)
  ensure
    Settings.save
  end

  private

  # Handles command-line options and returns a +Hash+ of the extracted options.
  def self.handle_options
    options = { debug: false }

    parser = OptionParser.new do |opts|
      opts.banner = 'Usage: droxi [OPTION ...] [COMMAND [ARGUMENT ...]]'

      opts.separator ''
      HELP_TEXT.each do |text|
        Text.wrap(text).each { |s| opts.separator(s) }
        opts.separator ''
      end
      opts.separator 'Options:'

      opts.on('--debug', 'Enable debug command') { options[:debug] = true }

      opts.on('-f', '--file FILE', String,
              'Specify path of config file') do |path|
        Settings.config_file_path = path
      end

      opts.on('-h', '--help', 'Print help information and exit') do
        puts opts
        exit
      end

      opts.on('--version', 'Print version information and exit') do
        puts "droxi v#{VERSION}"
        exit
      end
    end

    begin
      parser.parse!
    rescue OptionParser::ParseError => err
      warn(err)
      exit(1)
    end

    options
  end

  # Invokes a single command formed by joining an +Array+ of +String+ args.
  def self.invoke(args, client, state)
    with_interrupt_handling { Commands.exec(join_cmd(args), client, state) }
  end

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
  def self.run_interactive(client, state, reenter)
    info = client.account_info
    if reenter
      state.pwd = state.oldpwd
    else
      puts "Logged in as #{info['display_name']} (#{info['email']})"
    end

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
