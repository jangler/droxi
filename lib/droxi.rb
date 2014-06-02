require 'dropbox_sdk'
require 'readline'

require_relative 'droxi/commands'
require_relative 'droxi/settings'
require_relative 'droxi/state'

module Droxi
  APP_KEY = '5sufyfrvtro9zp7'
  APP_SECRET = 'h99ihzv86jyypho'

  def self.authorize
    flow = DropboxOAuth2FlowNoRedirect.new(APP_KEY, APP_SECRET)

    authorize_url = flow.start()

    # Have the user sign in and authorize this app
    puts '1. Go to: ' + authorize_url
    puts '2. Click "Allow" (you might have to log in first)'
    puts '3. Copy the authorization code'
    print 'Enter the authorization code here: '
    code = gets.strip

    # This will fail if the user gave us an invalid authorization code
    begin
      access_token, user_id = flow.finish(code)
      Settings[:access_token] = access_token
    rescue DropboxError
      puts 'Invalid authorization code.'
    end
  end

  def self.get_access_token
    until Settings.include?(:access_token)
      authorize()
    end
    Settings[:access_token]
  end

  def self.prompt(info, state)
    "droxi #{info['email']}:#{state.pwd}> "
  end

  def self.file_complete(word, dir_only=false)
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
    Dir.entries(dir).map do |file|
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

  def self.dir_complete(word)
    file_complete(word, true)
  end

  def self.run
    client = DropboxClient.new(get_access_token)
    info = client.account_info
    puts "Logged in as #{info['display_name']} (#{info['email']})"

    state = State.new

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
      when 'LOCAL_FILE'
        file_complete(word)
      when 'LOCAL_DIR'
        dir_complete(word)
      when 'REMOTE_FILE'
        begin
          state.file_complete(client, word)
        rescue DropboxError
          []
        end
      when 'REMOTE_DIR'
        begin
          state.dir_complete(client, word)
        rescue DropboxError
          []
        end
      else
        []
      end

      options.map { |option| option.gsub(' ', '\ ').sub(/\\ $/, ' ') }
    end

    begin
      Readline.completion_append_character = nil
    rescue NotImplementedError
    end

    begin
      while line = Readline.readline(prompt(info, state), true)
        Commands.exec(line.chomp, client, state)
      end
      puts
    rescue Interrupt
      puts
    end

    state.pwd = '/'
    Settings.write
  end
end
