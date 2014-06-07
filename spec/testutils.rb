require 'dropbox_sdk'

require_relative '../lib/droxi/commands'
require_relative '../lib/droxi/settings'
require_relative '../lib/droxi/state'

# Module of helper methods for testing.
module TestUtils
  # The remote directory under which all test-related file manipulation should
  # take place.
  TEST_ROOT = '/testing'

  # Call the method on the reciever with the given args and return an +Array+
  # of lines of output from the method.
  def self.output_of(receiver, method, *args)
    lines = []
    receiver.send(method, *args) { |line| lines << line }
    lines
  end

  # Ensure that the remote directory structure under +TEST_ROOT+ contains the
  # given +Array+ of paths.
  def self.structure(client, state, *paths)
    paths.map { |path| "#{TEST_ROOT}/#{path}" }.each do |path|
      next if state.metadata(path)
      if File.extname(path).empty?
        Commands::MKDIR.exec(client, state, path)
      else
        put_temp_file(client, state, path)
      end
    end
  end

  # Ensure that the given remote paths under +TEST_ROOT+ do NOT exist.
  def self.not_structure(client, state, *paths)
    paths.map! { |path| "#{TEST_ROOT}/#{path}" }
    dead_paths = state.contents(TEST_ROOT).select { |p| paths.include?(p) }
    return if dead_paths.empty?
    Commands::RM.exec(client, state, '-r', *dead_paths)
  end

  # Ensure that the remote directory structure under +TEST_ROOT+ exactly
  # matches the given +Array+ of paths.
  def self.exact_structure(client, state, *paths)
    structure(client, state, *paths)
    paths.map! { |path| "#{TEST_ROOT}/#{path}" }
    dead_paths = state.contents(TEST_ROOT).reject { |p| paths.include?(p) }
    return if dead_paths.empty?
    Commands::RM.exec(client, state, '-r', *dead_paths)
  end

  # Returns a new +DropboxClient+ and +State+.
  def self.create_client_and_state
    client = DropboxClient.new(Settings[:access_token])
    [client, State.new(client)]
  end

  private

  # Creates a remote file at the given path.
  def self.put_temp_file(client, state, path)
    `[ -d testing ] || mkdir testing`
    basename = File.basename(path)
    `touch testing/#{basename}`
    real_stdout = $stdout
    $stdout = StringIO.new
    Commands::PUT.exec(client, state, "testing/#{basename}", path)
    $stdout = real_stdout
    `rm -rf testing`
  end
end
