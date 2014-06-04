# Manages persistent (session-independent) application state.
module Settings
  # Return the value of a setting, or +nil+ if the setting does not exist.
  def self.[](key)
    settings[key]
  end

  # Set the value of a setting.
  def self.[]=(key, value)
    if value != settings[key]
      self.dirty = true
      settings[key] = value
    end
  end

  # Return +true+ if the setting exists, +false+ otherwise.
  def self.include?(key)
    settings.include?(key)
  end

  # Delete the setting and return its value.
  def self.delete(key)
    if settings.include?(key)
      self.dirty = true
      settings.delete(key)
    end
  end

  # Write settings to disk.
  def self.save
    if dirty
      self.dirty = false
      require 'fileutils'
      FileUtils.mkdir_p(File.dirname(CONFIG_FILE_PATH))
      File.open(CONFIG_FILE_PATH, 'w') do |file|
        settings.each_pair { |k, v| file.write("#{k}=#{v}\n") }
        file.chmod(0600)
      end
    end
    nil
  end

  private

  # The path of the application's rc file.
  CONFIG_FILE_PATH = File.expand_path('~/.config/droxi/droxirc')

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
    if /^(.+?)=(.+)$/ =~ line
      key, value = Regexp.last_match[1].to_sym, Regexp.last_match[2]
      if [:access_token, :oldpwd].include?(key)
        { key => value }
      else
        warn_invalid(line)
      end
    else
      warn_invalid(line)
    end
  end

  # Read and parse the rc file.
  def self.read
    if File.exist?(CONFIG_FILE_PATH)
      File.open(CONFIG_FILE_PATH) do |file|
        file.each_line.reduce({}) { |a, e| a.merge(parse(e.strip)) }
      end
    else
      {}
    end
  end

  self.settings = read
  self.dirty = false
end
