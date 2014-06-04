# Manages persistent (session-independent) application state.
class Settings

  # The path of the application's rc file.
  CONFIG_FILE_PATH = File.expand_path('~/.config/droxi/droxirc')

  # Return the value of a setting, or +nil+ if the setting does not exist.
  def Settings.[](key)
    @@settings[key]
  end

  # Set the value of a setting.
  def Settings.[]=(key, value)
    if value != @@settings[key]
      @@dirty = true
      @@settings[key] = value
    end
  end

  # Return +true+ if the setting exists, +false+ otherwise.
  def Settings.include?(key)
    @@settings.include?(key)
  end

  # Delete the setting and return its value.
  def Settings.delete(key)
    if @@settings.include?(key)
      @@dirty = true
      @@settings.delete(key)
    end
  end

  # Write settings to disk.
  def Settings.save
    if @@dirty
      @@dirty = false
      require 'fileutils'
      FileUtils.mkdir_p(File.dirname(CONFIG_FILE_PATH))
      File.open(CONFIG_FILE_PATH, 'w') do |file|
        @@settings.each_pair { |k, v| file.write("#{k}=#{v}\n") }
        file.chmod(0600)
      end
    end
    nil
  end

  private

  # Print a warning for an invalid setting and return an empty +Hash+ (the
  # result of an invalid setting).
  def Settings.warn_invalid(line)
    warn "invalid setting: #{line}"
    {}
  end

  # Parse a line of the rc file and return a +Hash+ containing the resulting
  # setting data.
  def Settings.parse(line)
    if /^(.+?)=(.+)$/ =~ line
      key, value = $1.to_sym, $2
      if [:access_token, :oldpwd].include?(key)
        {key => value}
      else
        warn_invalid(line)
      end
    else
      warn_invalid(line)
    end
  end

  # Read and parse the rc file.
  def Settings.read
    if File.exist?(CONFIG_FILE_PATH)
      File.open(CONFIG_FILE_PATH) do |file|
        file.each_line.reduce({}) { |a, e| a.merge(parse(e.strip)) }
      end
    else
      {}
    end
  end

  @@settings = read
  @@dirty = false

end
