require 'fileutils'

CONFIG_FILE_PATH = File.expand_path('~/.config/rubox/ruboxrc')

class Settings
  def Settings.[](key)
    @@settings[key]
  end

  def Settings.[]=(key, value)
    prev_value = @@settings[key]
    @@settings[key] = value
    save_settings() if prev_value != value
    value
  end

  def Settings.include?(key)
    @@settings.include?(key)
  end

  private

  def Settings.invalid_setting(line)
    warn "invalid setting: #{line}"
    {}
  end

  def Settings.parse_setting(line)
    if /^(.+?)=(.+)$/ =~ line
      key, value = $1.to_sym, $2
      case key
      when :access_token then {key => value}
      else invalid_setting(line)
      end
    else
      invalid_setting(line)
    end
  end

  def Settings.read_settings
    if File.exists?(CONFIG_FILE_PATH)
      File.open(CONFIG_FILE_PATH) do |file|
        file.each_line.reduce({}) { |a, e| a.merge(parse_setting(e.strip)) }
      end
    else
      {}
    end
  end

  def Settings.save_settings()
    FileUtils.mkdir_p(File.dirname(CONFIG_FILE_PATH))
    File.open(CONFIG_FILE_PATH, 'w') do |file|
      @@settings.each_pair { |k, v| file.write("#{k}=#{v}\n") }
    end
  end

  @@settings = Settings.read_settings
end
