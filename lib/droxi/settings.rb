# Manages persistent (session-independent) application state.
module Settings
  class << self
    # The path of the application's rc file.
    attr_accessor :config_file_path
  end

  self.config_file_path = File.expand_path('~/.config/droxi/droxirc')

  # Return the value of a setting, or +nil+ if the setting does not exist.
  def self.[](key)
    settings[key]
  end

  # Set the value of a setting.
  def self.[]=(key, value)
    return value if value == settings[key]
    self.dirty = true
    settings[key] = value
  end

  # Return +true+ if the setting exists, +false+ otherwise.
  def self.include?(key)
    settings.include?(key)
  end

  # Delete the setting and return its value.
  def self.delete(key)
    return unless settings.include?(key)
    self.dirty = true
    settings.delete(key)
  end

  # Write settings to disk.
  def self.save
    return unless dirty
    self.dirty = false
    require 'fileutils'
    FileUtils.mkdir_p(File.dirname(config_file_path))
    File.open(config_file_path, 'w') do |file|
      settings.each_pair { |k, v| file.write("#{k}=#{v}\n") }
      file.chmod(0600)
    end
    nil
  end

  # Read and parse the rc file.
  def self.read
    self.dirty = false
    return {} unless File.exist?(config_file_path)
    File.open(config_file_path) do |file|
      file.each_line.reduce({}) { |a, e| a.merge(parse(e.strip)) }
    end
  end

  private

  class << self
    # +true+ if the settings have been modified since last write, +false+
    # otherwise.
    attr_accessor :dirty

    # A +Hash+ of setting keys to values.
    attr_accessor :settings
  end

  # Print a warning for an invalid setting and return an empty +Hash+ (the
  # result of an invalid setting).
  def self.warn_invalid(line)
    warn "invalid setting: #{line}"
    {}
  end

  # Parse a line of the rc file and return a +Hash+ containing the resulting
  # setting data.
  def self.parse(line)
    return warn_invalid(line) unless /^(.+?)=(.+)$/ =~ line
    key, value = Regexp.last_match[1].to_sym, Regexp.last_match[2]
    return warn_invalid(line) unless [:access_token, :oldpwd].include?(key)
    { key => value }
  end

  # Initialize settings by reading rc file.
  def self.init
    self.settings = read
  end
end
