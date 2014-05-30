require 'fileutils'

CONFIG_FILE_PATH = File.expand_path('~/.config/rubox/ruboxrc')

class Settings
  def Settings.[](key)
    @@settings[key]
  end

  def Settings.[]=(key, value)
    if value != @@settings[key]
      @@dirty = true
      @@settings[key] = value
    end
  end

  def Settings.include?(key)
    @@settings.include?(key)
  end

  def Settings.delete(key)
    if @@settings.include?(key)
      @@dirty = true
      @@settings.delete(key)
    end
  end

  def Settings.write
    if @@dirty
      @@dirty = false
      FileUtils.mkdir_p(File.dirname(CONFIG_FILE_PATH))
      File.open(CONFIG_FILE_PATH, 'w') do |file|
        @@settings.each_pair { |k, v| file.write("#{k}=#{v}\n") }
      end
    end
  end

  private

  def Settings.warn_invalid(line)
    warn "invalid setting: #{line}"
    {}
  end

  def Settings.parse(line)
    if /^(.+?)=(.+)$/ =~ line
      key, value = $1.to_sym, $2
      case key
      when :access_token then {key => value}
      else warn_invalid(line)
      end
    else
      warn_invalid(line)
    end
  end

  def Settings.read
    if File.exists?(CONFIG_FILE_PATH)
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
