# Special +Hash+ of remote file paths to cached file metadata.
class Cache < Hash
  # Add a metadata +Hash+ and its contents to the +Cache+ and return the
  # +Cache+.
  def add(metadata)
    store(metadata['path'], metadata)
    dirname = File.dirname(metadata['path'])
    if dirname != metadata['path']
      contents = fetch(dirname, {}).fetch('contents', nil)
      contents << metadata if contents && !contents.include?(metadata)
    end
    return self unless metadata.include?('contents')
    metadata['contents'].each { |content| add(content) }
    self
  end

  # Remove a path from the +Cache+ and return the +Cache+.
  def remove(path)
    recursive_remove(path)

    dir = File.dirname(path)
    return self unless fetch(dir, {}).include?('contents')
    fetch(dir)['contents'].delete_if { |item| item['path'] == path }

    self
  end

  # Return +true+ if the path's information is cached, +false+ otherwise.
  def full_info?(path, require_contents = true)
    info = fetch(path, nil)
    info && (!require_contents || !info['is_dir'] || info.include?('contents'))
  end

  private

  # Recursively remove a path and its sub-files and directories.
  def recursive_remove(path)
    if fetch(path, {}).include?('contents')
      fetch(path)['contents'].each { |item| recursive_remove(item['path']) }
    end

    delete(path)
  end
end
